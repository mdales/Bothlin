//
//  SidebarController.m
//  Bothlin
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

        self->_sidebarTree = [[SidebarItem alloc] initWithTitle:@"toplevel"
                                                     symbolName:nil
                                                       children:@[everything, groups, tags]];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}


#pragma mark - NSOutlineViewDataSource

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    NSLog(@"Number of child of %@", item);
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
    NSLog(@"Need child of %@", item);
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
    NSLog(@"can expand %@", item);
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
    SidebarItem *sidebarItem = (SidebarItem *)item;
    NSLog(@"cell for item %@", item);
    NSTableCellView *view = [outlineView makeViewWithIdentifier:@"ItemCell" owner:self];
    view.textField.stringValue = sidebarItem.title;
    view.imageView.image = sidebarItem.icon;

    return view;
}

@end
