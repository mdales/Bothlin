//
//  GridViewController.m
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 28/09/2023.
//

#import "GridViewController.h"
#import "Asset+CoreDataClass.h"
#import "Helpers.h"
#import "AssetPromiseProvider.h"

@interface GridViewController ()

@property (strong, nonatomic, readonly) dispatch_queue_t syncQ;
@property (strong, nonatomic, readonly) dispatch_queue_t thumbnailLoadQ;

// Access only on syncQ
@property (strong, nonatomic, readwrite) NSArray<Asset *> *contents;
@property (strong, nonatomic, readwrite) NSDictionary<NSManagedObjectID *, NSImage *> *thumbnailCache;

@end

@implementation GridViewController

- (instancetype)initWithNibName:(NSNibName)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (nil != self) {
        self->_syncQ = dispatch_queue_create("com.digitalflapjack.GridViewController.syncQ", DISPATCH_QUEUE_SERIAL);
        self->_thumbnailLoadQ = dispatch_queue_create("com.digitalflapjack.GridViewController.thumbnailLoadQ", DISPATCH_QUEUE_CONCURRENT);
        self->_contents = @[];
        self->_thumbnailCache = @{};
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.collectionView setDraggingSourceOperationMask:NSDragOperationCopy
                                               forLocal:NO];
//    self.dragTargetView.delegate = self;
}

#pragma mark - Data management

- (void)setAssets:(NSArray<Asset *> *)assets withSelected:(NSSet<NSIndexPath *> *)indexPaths {
    NSParameterAssert(nil != assets);
    NSParameterAssert(nil != indexPaths);
    dispatch_assert_queue(dispatch_get_main_queue());

    __block BOOL updated = NO;
    __block NSSet<NSIndexPath *> *updatedCells = [NSSet set];
    if ([assets count] == [self.contents count]) {
        [assets enumerateObjectsUsingBlock:^(Asset * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            Asset *existingAsset = [self.contents objectAtIndex:idx];
            if (obj.objectID != existingAsset.objectID) {
                *stop = YES;
                updated = YES;
            }
            if (NO != [obj isFault]) {
                // If this object has either never been rendered, or it's on screen
                // and has been udpated, so we need to udpate the item view. Ideally
                // we'd filter out those who have never been visualised
                updatedCells = [updatedCells setByAddingObject:[NSIndexPath indexPathForItem:(NSInteger)idx inSection:0]];
            }
        }];
    } else {
        updated = YES;
    }
    if (NO != updated) {
        self.contents = assets;
    }

    NSIndexSet *currentSelection = [self.collectionView selectionIndexes];
    NSMutableSet<NSIndexPath *> *reformedCurrent = [NSMutableSet set];
    [currentSelection enumerateIndexesUsingBlock:^(NSUInteger idx, __unused BOOL * _Nonnull stop) {
        [reformedCurrent addObject:[NSIndexPath indexPathForItem:(NSInteger)idx inSection:0]];
    }];
    BOOL updatedSelection = ![indexPaths isEqualToSet:reformedCurrent];

    if (NO != updated) {
        [self.collectionView reloadData];
    } else {
        if (nil != updatedCells) {
            [self.collectionView reloadItemsAtIndexPaths:updatedCells];
        }
    }
    if ((NO != updatedSelection) && ([indexPaths count] > 0)) {
        [self.collectionView selectItemsAtIndexPaths:indexPaths
                                      scrollPosition:NSCollectionViewScrollPositionTop];
    }
}

- (void)selectionChanged {
    NSIndexSet *selectedRanges = [self.collectionView selectionIndexes];
    NSMutableSet<NSIndexPath *> *collectedIndexPaths = [NSMutableSet set];
    [selectedRanges enumerateIndexesUsingBlock:^(NSUInteger idx, __unused BOOL * _Nonnull stop) {
        [collectedIndexPaths addObject:[NSIndexPath indexPathForItem:(NSInteger)idx inSection:0]];
    }];
    [self.delegate gridViewController:self
                   selectionDidChange:[NSSet setWithSet:collectedIndexPaths]];
}


#pragma mark - NSCollectionViewDataSource

- (NSInteger)numberOfSectionsInCollectionView:(NSCollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    __block NSUInteger count = 0;
    dispatch_sync(self.syncQ, ^{
        count = [self.contents count];
    });

    return (NSInteger)count;
}

- (NSCollectionViewItem *)collectionView:(NSCollectionView *)collectionView itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath {
    NSParameterAssert(nil != indexPath);
    NSAssert(NSNotFound != [indexPath item], @"Got empty index path");
    dispatch_assert_queue(dispatch_get_main_queue());
    dispatch_assert_queue_not(self.syncQ);

    __block Asset *asset = nil;
    dispatch_sync(self.syncQ, ^{
        asset = [self.contents objectAtIndex:(NSUInteger)[indexPath item]];
    });

    GridViewItem *viewItem = [collectionView makeItemWithIdentifier:@"GridViewItem"
                                                       forIndexPath:indexPath];
    viewItem.delegate = self;
    viewItem.asset = asset;
    viewItem.textField.stringValue = asset.name;
    [viewItem.favouriteIndicator setHidden:NO == asset.favourite];

    __block NSImage *thumbnail = nil;
    dispatch_sync(self.syncQ, ^{
        thumbnail = self.thumbnailCache[asset.objectID];
    });
    if (nil == thumbnail) {
        NSString *thumbnailPath = asset.thumbnailPath;
        @weakify(self);
        @weakify(viewItem);
        dispatch_async(self.thumbnailLoadQ, ^{
            @strongify(self);
            if (nil == self) {
                return;
            }
            NSImage *thumbnail = nil;
            if (nil != thumbnailPath) {
                thumbnail = [[NSImage alloc] initByReferencingFile:thumbnailPath];
                if (nil != thumbnail) {
                    dispatch_sync(self.syncQ, ^{
                        NSMutableDictionary<NSManagedObjectID *, NSImage *> *tmp = [NSMutableDictionary dictionaryWithDictionary:self.thumbnailCache];
                        tmp[asset.objectID] = thumbnail;
                        self.thumbnailCache = [NSDictionary dictionaryWithDictionary:tmp];
                    });
                } else {
                    NSLog(@"Failed to load %@", thumbnailPath);
                }
            }
            if (nil == thumbnail) {
                thumbnail = [NSImage imageWithSystemSymbolName:@"exclamationmark.square" accessibilityDescription:nil];
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                @strongify(viewItem);
                if (nil == viewItem) {
                    return;
                }
                viewItem.imageView.image = thumbnail;
            });
        });

        thumbnail = [NSImage imageWithSystemSymbolName:@"photo.artframe" accessibilityDescription:nil];
    }
    viewItem.imageView.image = thumbnail;

    return viewItem;
}


#pragma mark - NSCollectionViewDelegate Drag Out

- (BOOL)collectionView:(NSCollectionView *)collectionView canDragItemsAtIndexes:(NSIndexSet *)indexes withEvent:(NSEvent *)event {
    return YES;
}

- (id<NSPasteboardWriting>)collectionView:(NSCollectionView *)collectionView pasteboardWriterForItemAtIndexPath:(NSIndexPath *)indexPath {
    NSParameterAssert(nil != indexPath);

    // This is a bit of an odd arrangement, due to how drag was originally implemented
    GridViewItem *item = (GridViewItem *)[self.collectionView itemAtIndexPath:indexPath];
    AssetPromiseProvider *provider = [[AssetPromiseProvider alloc] initWithFileType:item.asset.type
                                                                           delegate:item]; // TODO: shoudl be self

    NSError *error = nil;
    NSData *archivedIndexPath = [NSKeyedArchiver archivedDataWithRootObject:indexPath
                                                      requiringSecureCoding:YES
                                                                      error:&error];
    NSAssert(nil == error, @"Failed to archive indexPath %@: %@", indexPath, error);

    provider.userInfo = @{
        kAssetPromiseProviderURLKey:[NSURL fileURLWithPath:item.asset.path],
        kAssetPromiseProviderIndexPathKey:archivedIndexPath
    };
    return provider;
}


#pragma mark - NSCollectionViewDelegate Drag In

- (NSDragOperation)collectionView:(NSCollectionView *)collectionView 
                     validateDrop:(id<NSDraggingInfo>)draggingInfo
                proposedIndexPath:(NSIndexPath * _Nonnull __autoreleasing *)proposedDropIndexPath
                    dropOperation:(NSCollectionViewDropOperation *)proposedDropOperation {
    // if the source of the drag is this collection view, ignore it as we don't support
    // re-arranging of items.
    id draggingSource = [draggingInfo draggingSource];
    if (draggingSource == self.collectionView) {
        return NSDragOperationNone;
    }

    // TODO: probably see what other sources there area
    return NSDragOperationCopy;
}

- (BOOL)collectionView:(NSCollectionView *)collectionView 
            acceptDrop:(id<NSDraggingInfo>)draggingInfo
                 index:(NSInteger)index
         dropOperation:(NSCollectionViewDropOperation)dropOperation {
    dispatch_assert_queue(dispatch_get_main_queue());
    id<GridViewControllerDelegate> delegate = self.delegate;
    if (nil == delegate) {
        return NO;
    }

    NSPasteboard *pasteboard = draggingInfo.draggingPasteboard;
    if (nil == pasteboard) {
        return NO;
    }
    NSArray<NSURL *> *objects = [pasteboard readObjectsForClasses:@[[NSURL class]]
                                                          options:nil];
    return [delegate gridViewController:self
                  didReceiveDroppedURLs:[NSSet setWithArray:objects]];
}

#pragma mark - NSCollectionViewDelegate General

- (void)collectionView:(NSCollectionView *)collectionView didSelectItemsAtIndexPaths:(__unused NSSet<NSIndexPath *> *)indexPaths {
    // The item passed to us here is just what was added, not the entire set, so we need to build that ourselves
    [self selectionChanged];
}

- (void)collectionView:(NSCollectionView *)collectionView didDeselectItemsAtIndexPaths:(__unused NSSet<NSIndexPath *> *)indexPaths {
    // This again is just the changes, and for now we want to have just the final amount
    [self selectionChanged];
}


#pragma mark - GridViewItemDelegate

- (void)gridViewItemWasDoubleClicked:(GridViewItem *)gridViewItem {
    [self.delegate gridViewController:self
                    doubleClickedItem:gridViewItem.asset];
}

- (BOOL)gridViewItem:(GridViewItem *)gridViewItem wasDraggedOnSidebarItem:(SidebarItem *)sidebarItem {
    // TODO: What happens on multiple drag?
    id<GridViewControllerDelegate> delegate = self.delegate;
    if (nil == delegate) {
        return NO;
    }
    return [delegate gridViewController:self
                                 assets:[NSSet setWithObject:gridViewItem.asset]
                wasDraggedOnSidebarItem:sidebarItem];
}


#pragma mark - DragTargetViewDelegate

- (BOOL)dragTargetView:(DragTargetView *)dragTargetView handleDrag:(id<NSDraggingInfo> _Nonnull)dragInfo {
    dispatch_assert_queue(dispatch_get_main_queue());
    id<GridViewControllerDelegate> delegate = self.delegate;
    if (nil == delegate) {
        return NO;
    }

    NSPasteboard *pasteboard = dragInfo.draggingPasteboard;
    if (nil == pasteboard) {
        return NO;
    }
    NSArray<NSURL *> *objects = [pasteboard readObjectsForClasses:@[[NSURL class]]
                                                          options:nil];
    return [delegate gridViewController:self
                  didReceiveDroppedURLs:[NSSet setWithArray:objects]];
}

@end
