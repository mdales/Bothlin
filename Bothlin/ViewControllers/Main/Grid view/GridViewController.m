//
//  GridViewController.m
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 28/09/2023.
//

#import "GridViewController.h"
#import "Asset+CoreDataClass.h"
#import "Helpers.h"

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
    self.dragTargetView.delegate = self;
}

#pragma mark - Data management

- (void)setAssets:(NSArray<Asset *> *)assets withSelected:(NSIndexPath *)indexPath {
    NSParameterAssert(nil != indexPath);
    dispatch_assert_queue(dispatch_get_main_queue());
    __block BOOL updated = NO;
    __block NSIndexPath *updatedCells = nil;
    if ([assets count] == [self.contents count]) {
        [assets enumerateObjectsUsingBlock:^(Asset * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            Asset *existingAsset = [self.contents objectAtIndex:idx];
            if (obj.objectID != existingAsset.objectID) {
                *stop = YES;
                updated = YES;
            }
            if (NO != [obj isFault]) {
                // If this object has either never been rendered, or it's on screen
                // and has been udpated, so we need to udpate the item view.
                if (nil == updatedCells) {
                    updatedCells = [NSIndexPath indexPathForItem:(NSInteger)idx inSection:0];
                } else {
                    updatedCells = [updatedCells indexPathByAddingIndex:idx];
                }
            }
        }];
    } else {
        updated = YES;
    }
    if (NO != updated) {
        self.contents = assets;
    }

    BOOL updatedSelection = NO;
    NSInteger index = [indexPath item];
    if (NSNotFound != index) {
        NSIndexSet *currentSelection = [self.collectionView selectionIndexes];
        NSAssert([currentSelection count] < 2, @"We currently allow just one selection!");
        if (0 == [currentSelection count]) {
            updatedSelection = YES;
        } else {
            NSUInteger current = [currentSelection firstIndex];
            if (current != index) {
                updatedSelection = YES;
            }
        }
    }

    if (NO != updated) {
        [self.collectionView reloadData];
    } else {
        if (nil != updatedCells) {
            [self.collectionView reloadItemsAtIndexPaths:[NSSet setWithObject:updatedCells]];
        }
    }
    if ((NO != updatedSelection) && (NSNotFound != index)) {
        [self.collectionView selectItemsAtIndexPaths:[NSSet setWithObject:indexPath]
                                      scrollPosition:NSCollectionViewScrollPositionTop];
    }
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
            }
            if (nil == thumbnail) {
                thumbnail = [NSImage imageWithSystemSymbolName:@"exclamationmark.square" accessibilityDescription:nil];
            }

            dispatch_sync(self.syncQ, ^{
                NSMutableDictionary<NSManagedObjectID *, NSImage *> *tmp = [NSMutableDictionary dictionaryWithDictionary:self.thumbnailCache];
                tmp[asset.objectID] = thumbnail;
                self.thumbnailCache = [NSDictionary dictionaryWithDictionary:tmp];
            });

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

#pragma mark - NSCollectionViewDelegate

- (void)collectionView:(NSCollectionView *)collectionView didSelectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths {
    // TODO: One day, support multiple items
    NSAssert(1 == [indexPaths count], @"User selected more/less than one item: %lu", [indexPaths count]);
    NSIndexPath *indexPath = [indexPaths anyObject];
    [self.delegate gridViewController:self
                   selectionDidChange:indexPath];
}

- (void)collectionView:(NSCollectionView *)collectionView didDeselectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths {
    NSAssert(1 == [indexPaths count], @"User selected more/less than one item: %lu", [indexPaths count]);
    [self.delegate gridViewController:self
                   selectionDidChange:[[NSIndexPath alloc] init]];
}


#pragma mark - GridViewItemDelegate

- (void)gridViewItemWasDoubleClicked:(GridViewItem *)gridViewItem {
    [self.delegate gridViewController:self
                    doubleClickedItem:gridViewItem.asset];
}

- (BOOL)gridViewItem:(GridViewItem *)gridViewItem wasDraggedOnSidebarItem:(SidebarItem *)sidebarItem {
    if (nil == self.delegate) {
        return NO;
    }
    return [self.delegate gridViewController:self
                                        item:gridViewItem.asset
                     wasDraggedOnSidebarItem:sidebarItem];
}


#pragma mark - DragTargetViewDelegate

- (BOOL)dragTargetView:(DragTargetView *)dragTargetView handleDrag:(id<NSDraggingInfo> _Nonnull)dragInfo {
    dispatch_assert_queue(dispatch_get_main_queue());
    if (nil == self.delegate) {
        return NO;
    }

    NSPasteboard *pasteboard = dragInfo.draggingPasteboard;
    if (nil == pasteboard) {
        return NO;
    }
    NSArray<NSURL *> *objects = [pasteboard readObjectsForClasses:@[[NSURL class]]
                                                          options:nil];
    [self.delegate gridViewController:self
                didReceiveDroppedURLs:[NSSet setWithArray:objects]];
    
    return YES;
}

@end
