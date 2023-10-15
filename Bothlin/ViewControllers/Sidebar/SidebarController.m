//
//  SidebarController.m
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 28/09/2023.
//

#import "SidebarController.h"
#import "SidebarItem.h"
#import "NSArray+Functional.h"
#import "TableCellWithButtonView.h"
#import "AppDelegate.h"
#import "Group+CoreDataClass.h"

NSArray<NSString *> * const testTags = @[
    @"Minecraft",
    @"QGIS",
    @"Other",
];

@interface SidebarController ()

// Safe on mainQ only
@property (nonatomic, strong, readwrite) SidebarItem * _Nonnull sidebarTree;

@end

@implementation SidebarController

- (void)rebuildMenu {
    dispatch_assert_queue(dispatch_get_main_queue());

    SidebarItem *everything = [[SidebarItem alloc] initWithTitle:@"Everything"
                                                      symbolName:@"shippingbox"
                                                        children:nil];

    SidebarItem *favourites = [[SidebarItem alloc] initWithTitle:@"Favourites"
                                                      symbolName:@"heart"
                                                        children:nil];

    AppDelegate *appDelegate = (AppDelegate *)([NSApplication sharedApplication].delegate);
    NSManagedObjectContext *context = appDelegate.persistentContainer.viewContext;
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"Group"];
    NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"name"
                                                           ascending:YES];
    [fetchRequest setSortDescriptors:@[sort]];
    NSError *error = nil;
    NSArray<Group *> *groups = [context executeFetchRequest:fetchRequest
                                                      error:&error];
    if (nil != error) {
        NSAssert(nil == groups, @"Got error and groups");
        // TODO: Need to take corrective action for corrupt data?
        NSLog(@"Failed to fetch groups: %@", error);
        groups = @[];
    }
    NSAssert(nil != groups, @"Got no error and no groups");

    SidebarItem *groupsItem = [[SidebarItem alloc] initWithTitle:@"Groups"
                                                      symbolName:@"folder"
                                                        children:[groups mapUsingBlock:^SidebarItem * _Nonnull(Group * _Nonnull group) {
        return [[SidebarItem alloc] initWithTitle:group.name
                                       symbolName:nil
                                         children:nil];
    }]];

    SidebarItem *tags = [[SidebarItem alloc] initWithTitle:@"Popular Tags"
                                                symbolName:@"tag"
                                                  children:[testTags mapUsingBlock:^SidebarItem * _Nonnull(NSString * _Nonnull title) {
        return [[SidebarItem alloc] initWithTitle:title
                                       symbolName:nil
                                         children:nil];
    }]];

    SidebarItem *trash = [[SidebarItem alloc] initWithTitle:@"Trash"
                                                 symbolName:@"trash"
                                                   children:nil];

    self->_sidebarTree = [[SidebarItem alloc] initWithTitle:@"toplevel"
                                                 symbolName:nil
                                                   children:@[everything, favourites, groupsItem, tags, trash]];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self rebuildMenu];
    [self.outlineView reloadData];
    [self.outlineView selectRowIndexes:[[NSIndexSet alloc] initWithIndex:0]
                  byExtendingSelection:NO];
}

- (void)reloadData {
    dispatch_assert_queue(dispatch_get_main_queue());
    [self rebuildMenu];
    [self.outlineView reloadData];
}

- (void)showGroups {
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
    return 0 == [sidebarItem.children count];
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

@end
