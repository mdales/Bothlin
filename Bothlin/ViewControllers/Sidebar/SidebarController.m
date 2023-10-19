//
//  SidebarController.m
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 28/09/2023.
//

#import "SidebarController.h"
#import "SidebarItem.h"
#import "TableCellWithButtonView.h"

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
    if (nil == item) {
        if (nil != self.sidebarTree.children) {
            return [self.sidebarTree.children objectAtIndex:(NSUInteger)index];
        }
    } else if ([item isKindOfClass:[SidebarItem class]]) {
        SidebarItem *sidebarItem = (SidebarItem *)item;
        if (nil != sidebarItem.children) {
            return [sidebarItem.children objectAtIndex:(NSUInteger)index];
        }
    }
    return nil;
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
             didChangeSelectedOption:item.fetchRequest];
}

- (NSDragOperation)outlineView:(NSOutlineView *)outlineView validateDrop:(id<NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(NSInteger)index {
    if (nil == item) {
        return NSDragOperationNone;
    }
    NSAssert([item isKindOfClass:[SidebarItem class]], @"Unexpected class for item");
    SidebarItem *sidebarItem = (SidebarItem *)item;
    return (sidebarItem.fetchRequest == nil) ? NSDragOperationNone : NSDragOperationCopy;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView acceptDrop:(id<NSDraggingInfo>)info item:(id)item childIndex:(NSInteger)index {
    if (nil == item) {
        return NO;
    }
    NSAssert([item isKindOfClass:[SidebarItem class]], @"Unexpected class for item");
    SidebarItem *sidebarItem = (SidebarItem *)item;
    return (sidebarItem.fetchRequest != nil);
}

@end
