//
//  SidebarController.m
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 28/09/2023.
//

#import "SidebarController.h"
#import "SidebarItem.h"
#import "TableCellWithButtonView.h"
#import "DragSourceView.h"
#import "GridViewItem.h"
#import "AssetPromiseProvider.h"

@implementation SidebarController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self.outlineView registerForDraggedTypes:NSFilePromiseReceiver.readableDraggedTypes];

    [self.outlineView reloadData];
    [self.outlineView selectRowIndexes:[[NSIndexSet alloc] initWithIndex:0]
                  byExtendingSelection:NO];
}

- (void)setSidebarTree:(SidebarItem *)sidebarTree {
    NSParameterAssert(nil != sidebarTree);
    dispatch_assert_queue(dispatch_get_main_queue());
    self->_sidebarTree = sidebarTree;
    [self.outlineView reloadData];
}

- (void)expandGroupsBranch {
    for (SidebarItem *item in self.sidebarTree.children) {
        if ([item.title compare:@"Groups"] == NSOrderedSame) {
            [self.outlineView expandItem:item];
            break;
        }
    }
}

- (IBAction)addItemFromOutlineView:(id)sender {
    [self.delegate addGroupViaSidebarController: self];
}

- (NSFetchRequest *)selectedOption {
    SidebarItem *item = [self.outlineView itemAtRow:[self.outlineView selectedRow]];
    NSAssert(nil != item.fetchRequest, @"selected item with no fetch request");
    return item.fetchRequest;
}


#pragma mark - NSOutlineViewDataSource

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    if (nil == item) {
        return (NSInteger)[self.sidebarTree.children count];
    } else if ([item isKindOfClass:[SidebarItem class]]) {
        SidebarItem *sidebarItem = (SidebarItem *)item;
        if (nil != sidebarItem.children) {
            return (NSInteger)[sidebarItem.children count];
        } else {
            return 0;
        }
    }
    return 1;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
    // Not allowed to return nil, so just assert incase we medded out the numberOfChildrenOfItem
    if (nil == item) {
        NSAssert(nil != self.sidebarTree.children, @"No sidebar tree!");
        return [self.sidebarTree.children objectAtIndex:(NSUInteger)index];
    }
    NSAssert([item isKindOfClass:[SidebarItem class]], @"Unexpected item in sidebar area %@", item);
    SidebarItem *sidebarItem = (SidebarItem *)item;
    NSAssert(nil != sidebarItem.children, @"wrong number of children for %@", item);
    return [sidebarItem.children objectAtIndex:(NSUInteger)index];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    if (nil == item) {
        return NO;
    } else if ([item isKindOfClass:[SidebarItem class]]) {
        SidebarItem *sidebarItem = (SidebarItem *)item;
        return (nil != sidebarItem.children) || ([sidebarItem.children count] > 0);
    }
    return NO;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item {
    NSAssert([item isKindOfClass:[SidebarItem class]], @"Cell item not of expected type");
    SidebarItem *sidebarItem = (SidebarItem *)item;
    return nil != sidebarItem.fetchRequest;
}

#pragma mark - NSOutlineViewDelegate

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    NSAssert([item isKindOfClass:[SidebarItem class]], @"Cell item not of expected type");
    SidebarItem *sidebarItem = (SidebarItem *)item;

    NSString *cellType = @"ItemCell";
    if (nil != sidebarItem.icon) {
        cellType = ([sidebarItem.title compare:@"Groups"] == NSOrderedSame) ? @"AddItemCell" : @"TopLevelItemCell";
    }

    NSTableCellView *view = [outlineView makeViewWithIdentifier:cellType
                                                          owner:self];
    NSAssert(nil != view, @"Failed to get outline view cell");
    view.textField.stringValue = sidebarItem.title;
    view.imageView.image = sidebarItem.icon;

    return view;
}

- (CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item {
    NSAssert([item isKindOfClass:[SidebarItem class]], @"Cell item not of expected type");
    SidebarItem *sidebarItem = (SidebarItem *)item;
    return sidebarItem.icon ? 32.0 : 24.0;
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
    SidebarItem *item = [self.outlineView itemAtRow:[self.outlineView selectedRow]];
    NSAssert(nil != item.fetchRequest, @"selected item with no fetch request");
    [self.delegate sidebarController:self
             didChangeSelectedOption:item];
}

- (NSDragOperation)outlineView:(NSOutlineView *)outlineView 
                  validateDrop:(id<NSDraggingInfo>)info
                  proposedItem:(id)item
            proposedChildIndex:(NSInteger)index {
    if (nil == item) {
        return NSDragOperationNone;
    }
    NSAssert([item isKindOfClass:[SidebarItem class]], @"Unexpected class for item");
    SidebarItem *sidebarItem = (SidebarItem *)item;
    return (sidebarItem.dragResponseType == SidebarItemDragResponseNone) ? NSDragOperationNone : NSDragOperationCopy;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView 
         acceptDrop:(id<NSDraggingInfo>)draggingInfo
               item:(id)item
         childIndex:(NSInteger)index {
    NSParameterAssert(nil != item);
    NSParameterAssert([item isKindOfClass:[SidebarItem class]]);
    id<SidebarControllerDelegate> delegate = self.delegate;
    if (nil == delegate) {
        return NO;
    }
    SidebarItem *sidebarItem = (SidebarItem *)item;
    if (SidebarItemDragResponseNone == sidebarItem.dragResponseType) {
        return NO;
    }

    if (NO == [[draggingInfo draggingSource] isKindOfClass:[NSCollectionView class]]) {
        return NO;
    }
    NSCollectionView *source = (NSCollectionView *)[draggingInfo draggingSource];
    NSMutableSet<NSIndexPath *> *indexPathSet = [NSMutableSet set];
    [draggingInfo enumerateDraggingItemsWithOptions:NSDraggingItemEnumerationConcurrent // TODO: copied from example, feels unsafe
                                            forView:source
                                            classes:@[[NSPasteboardItem class]]
                                      searchOptions:@{}
                                         usingBlock:^(NSDraggingItem * _Nonnull draggingItem, __unused NSInteger idx, __unused BOOL * _Nonnull stop) {
        if ([draggingItem.item isKindOfClass:[NSPasteboardItem class]]) {
            NSPasteboardItem *item = (NSPasteboardItem *)draggingItem.item;
            if ([item.types indexOfObject:kAssetProviderType] == NSNotFound) {
                return;
            }

            id maybedata = [item dataForType:kAssetProviderType];
            if (nil == maybedata) {
                return;
            }
            NSError *error = nil;
            id maybeIndexPath = [NSKeyedUnarchiver unarchiveTopLevelObjectWithData:maybedata
                                                                             error:&error];
            if (nil != error) {
                NSAssert(nil == maybeIndexPath, @"got error and data");
                NSLog(@"error: %@", error);
                return;
            }
            NSAssert(nil != maybeIndexPath, @"Got no error but no data");
            NSAssert([maybeIndexPath isKindOfClass:[NSIndexPath class]], @"expected index path");
            [indexPathSet addObject:maybeIndexPath];
        }
    }];

    if ([indexPathSet count] == 0) {
        return NO;
    }

    return [delegate sidebarController:self
                    recievedIndexPaths:[NSSet setWithSet:indexPathSet]
                                onItem:item];
}

@end
