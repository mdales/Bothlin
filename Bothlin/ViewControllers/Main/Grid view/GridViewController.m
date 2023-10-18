//
//  GridViewController.m
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 28/09/2023.
//

#import "GridViewController.h"
#import "Item+CoreDataClass.h"
#import "Helpers.h"

@interface GridViewController ()

@property (strong, nonatomic, readonly) dispatch_queue_t syncQ;
@property (strong, nonatomic, readonly) dispatch_queue_t thumbnailLoadQ;

// Access only on syncQ
@property (strong, nonatomic, readwrite) NSArray<Item *> *contents;
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

- (void)setItems:(NSArray<Item *> *)items withSelected:(Item *)selected {
    dispatch_assert_queue(dispatch_get_main_queue());
    __block BOOL updated = NO;
    // TODO: at some point this needs to generate the update indexes so we don't just reload the table
    if ([items count] == [self.contents count]) {
        [items enumerateObjectsUsingBlock:^(Item * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            Item *existingItem = [self.contents objectAtIndex:idx];
            if (obj.objectID != existingItem.objectID) {
                *stop = YES;
                updated = YES;
            }
        }];
    } else {
        updated = YES;
    }
    if (NO != updated) {
        self.contents = items;
    }
    // TODO: at some point we should just update the selected and not reload the table
    if (selected != self.selectedItem) {
        self.selectedItem = selected;
        updated = YES;
    }
    if (NO != updated) {
        [self.collectionView reloadData];
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
    dispatch_assert_queue(dispatch_get_main_queue());
    dispatch_assert_queue_not(self.syncQ);

    __block Item *item = nil;
    dispatch_sync(self.syncQ, ^{
        item = [self.contents objectAtIndex:(NSUInteger)indexPath.item];
    });

    GridViewItem *viewItem = [collectionView makeItemWithIdentifier:@"GridViewItem"
                                                       forIndexPath:indexPath];
    viewItem.delegate = self;
    viewItem.item = item;
    viewItem.textField.stringValue = item.name;

    __block NSImage *thumbnail = nil;
    dispatch_sync(self.syncQ, ^{
        thumbnail = self.thumbnailCache[item.objectID];
    });

    if (nil == thumbnail) {
        NSString *thumbnailPath = item.thumbnailPath;
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
                tmp[item.objectID] = thumbnail;
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
    NSAssert(1 == [indexPaths count], @"User selected more/less than one item: %lu", [indexPaths count]);
    NSIndexPath *indexPath = [indexPaths anyObject];

    __block Item *item = nil;
    dispatch_sync(self.syncQ, ^{
        item = self.contents[(NSUInteger)indexPath.item];
    });

    self.selectedItem = item;
    if (nil != self.delegate) {
        [self.delegate gridViewController:self
                       selectionDidChange:item];
    }
}


#pragma mark - GridViewItemDelegate

- (void)gridViewItemWasDoubleClicked:(GridViewItem *)gridViewItem {
    [self.delegate gridViewController:self
                    doubleClickedItem:gridViewItem.item];
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
