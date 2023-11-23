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
#import "NSArray+Functional.h"

@interface GridViewController ()

@property (strong, nonatomic, readonly) dispatch_queue_t syncQ;
@property (strong, nonatomic, readonly) dispatch_queue_t thumbnailLoadQ;

// Access only on syncQ
@property (strong, nonatomic, readwrite) NSArray<Asset *> *contents;
@property (strong, nonatomic, readwrite) NSDictionary<NSManagedObjectID *, NSImage *> *thumbnailCache;

@property (strong, nonatomic, readwrite) NSCollectionViewDiffableDataSource<NSNumber *, Asset *> *dataSource;

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

    self.collectionView.keyDelegate = self;
    self.dragTargetView.delegate = self; 

    [self.collectionView setDraggingSourceOperationMask:NSDragOperationCopy
                                               forLocal:NO];

    self.dataSource = [[NSCollectionViewDiffableDataSource alloc] initWithCollectionView:self.collectionView
                                                                            itemProvider:^NSCollectionViewItem * _Nullable(NSCollectionView * _Nonnull collectionView,
                                                                                                                           NSIndexPath * _Nonnull indexPath,
                                                                                                                           Asset * _Nonnull asset) {
        dispatch_assert_queue(dispatch_get_main_queue());
        dispatch_assert_queue_not(self.syncQ);

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
            // TODO: move this code to a function
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
    }];

    self.collectionView.dataSource = self.dataSource;
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
        NSDiffableDataSourceSnapshot<NSNumber *, Asset *> *snapshot = [[NSDiffableDataSourceSnapshot alloc] init];
        [snapshot appendSectionsWithIdentifiers:@[@0]];
        [snapshot appendItemsWithIdentifiers:self.contents
                   intoSectionWithIdentifier:@0];
        [self.dataSource applySnapshot:snapshot
                  animatingDifferences:YES];
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

- (NSUInteger)count {
    dispatch_assert_queue_not(self.syncQ);

    __block NSUInteger count = 0;
    dispatch_sync(self.syncQ, ^{
        count = [self.contents count];
    });
    return count;
}

- (NSSet<NSIndexPath *> *)currentSelection {
    dispatch_assert_queue(dispatch_get_main_queue());

    NSIndexSet *selectedRanges = [self.collectionView selectionIndexes];
    NSMutableSet<NSIndexPath *> *collectedIndexPaths = [NSMutableSet set];
    [selectedRanges enumerateIndexesUsingBlock:^(NSUInteger idx, __unused BOOL * _Nonnull stop) {
        [collectedIndexPaths addObject:[NSIndexPath indexPathForItem:(NSInteger)idx inSection:0]];
    }];
    return [NSSet setWithSet:collectedIndexPaths];
}

- (BOOL)currentSelectedItemFrame:(NSRect *)frame {
    dispatch_assert_queue(dispatch_get_main_queue());
    NSParameterAssert(nil != frame);

    NSSet<NSIndexPath *> *collectedIndexPaths = [self currentSelection];
    if ([collectedIndexPaths count] != 1) {
        return NO;
    }

    NSCollectionViewItem *selected = [self.collectionView itemAtIndexPath:[collectedIndexPaths anyObject]];
    *frame = [selected.view convertRect:selected.imageView.frame toView:self.view];

    return YES;
}


#pragma mark - internal

- (void)selectionChanged {
    // If we're left with an empty selection, then do not send an update, as the collectionView
    // is not allowed to have no selection, and thus we know a selection will be coming along
    // soon - there is no atomic selection change notification that wraps up changing selection
    // AFAICT
    if ([self.collectionView.selectionIndexPaths count] == 0) {
        return;
    }

    NSIndexSet *selectedRanges = [self.collectionView selectionIndexes];
    NSMutableSet<NSIndexPath *> *collectedIndexPaths = [NSMutableSet set];
    [selectedRanges enumerateIndexesUsingBlock:^(NSUInteger idx, __unused BOOL * _Nonnull stop) {
        [collectedIndexPaths addObject:[NSIndexPath indexPathForItem:(NSInteger)idx inSection:0]];
    }];
    [self.delegate gridViewController:self
                   selectionDidChange:[NSSet setWithSet:collectedIndexPaths]];
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


#pragma mark - KeyCollectionViewDelegate

- (BOOL)keyCollectionView:(__unused KeyCollectionView *)keyCollectionView
    presentItemsAtIndexes:(NSIndexSet *)indexes {
    dispatch_assert_queue(dispatch_get_main_queue());

    // get the first selected item
    if ([indexes count] < 1) {
        return NO;
    }

    __block Asset *asset = nil;
    dispatch_sync(self.syncQ, ^{
        NSUInteger index = [indexes firstIndex];
        if (index < [self.contents count]) {
            asset = self.contents[index];
        }
    });
    if (nil == asset) {
        return NO;
    }

    [self.delegate gridViewController:self
                    doubleClickedItem:asset];
    return YES;
}

@end
