//
//  SidebarController.m
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 28/09/2023.
//

#import "SidebarController.h"
#import "SidebarItem.h"
#import "NSArray+Functional.h"

NSArray<NSString *> * const testGroups = @[
    @"Project A",
    @"Work thing",
];

NSArray<NSString *> * const testTags = @[
    @"Minecraft",
    @"QGIS",
    @"Other",
];

@interface SidebarController ()

@property (nonatomic, strong, readonly) SidebarItem * _Nonnull sidebarTree;

@end

@implementation SidebarController

- (instancetype)initWithNibName:(NSNibName)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (nil != self) {

        SidebarItem *everything = [[SidebarItem alloc] initWithTitle:@"Everything"
                                                          symbolName:@"shippingbox"
                                                            children:nil];

        SidebarItem *favourites = [[SidebarItem alloc] initWithTitle:@"Favourites"
                                                          symbolName:@"heart"
                                                            children:nil];

        SidebarItem *groups = [[SidebarItem alloc] initWithTitle:@"Groups"
                                                      symbolName:@"folder"
                                                        children:[testGroups mapUsingBlock:^SidebarItem * _Nonnull(NSString * _Nonnull title) {
            return [[SidebarItem alloc] initWithTitle:title
                                           symbolName:nil
                                             children:nil];
        }]];

        SidebarItem *tags = [[SidebarItem alloc] initWithTitle:@"Tags"
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
                                                       children:@[everything, favourites, groups, tags, trash]];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self.outlineView selectRowIndexes:[[NSIndexSet alloc] initWithIndex:0]
                  byExtendingSelection:NO];
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

#pragma mark - NSOutlineViewDelegate

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    NSAssert([item isKindOfClass:[SidebarItem class]], @"Cell item not of expected type");
    SidebarItem *sidebarItem = (SidebarItem *)item;
    NSTableCellView *view = [outlineView makeViewWithIdentifier:nil != sidebarItem.icon ? @"TopLevelItemCell" : @"ItemCell"
                                                          owner:self];
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
