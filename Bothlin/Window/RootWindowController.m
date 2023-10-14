//
//  RootWindowController.m
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 28/09/2023.
//

#import "RootWindowController.h"
#import "SidebarController.h"
#import "ItemsDisplayController.h"
#import "DetailsController.h"
#import "AppDelegate.h"
#import "LibraryController.h"
#import "ToolbarProgressView.h"
#import "Helpers.h"

NSString * __nonnull const kImportToolbarItemIdentifier = @"ImportToolbarItemIdentifier";
NSString * __nonnull const kSearchToolbarItemIdentifier = @"SearchToolbarItemIdentifier";
NSString * __nonnull const kProgressToolbarItemIdentifier = @"ProgressToolbarItemIdentifier";
NSString * __nonnull const kItemDisplayStyleItemIdentifier = @"ItemDisplayStyleItemIdentifier";
NSString * __nonnull const kShareToolbarItemIdentifier = @"ShareToolbarItemIdentifier";
NSString * __nonnull const kDeleteToolbarItemIdentifier = @"DeleteToolbarItemIdentifier";
NSString * __nonnull const kToggleDetailViewToolbarItemIdentifier = @"ToggleDetailViewToolbarItemIdentifier";
NSString * __nonnull const kFavouriteToolbarItemIdentifier = @"FavouriteToolbarItemIdentifier";

@interface RootWindowController ()

@property (nonatomic, strong, readonly) SidebarController *sidebar;
@property (nonatomic, strong, readonly) ItemsDisplayController *itemsDisplay;
@property (nonatomic, strong, readonly) DetailsController *details;
@property (nonatomic, strong, readonly) NSSplitViewController *splitViewController;
@property (nonatomic, strong, readonly) ToolbarProgressView *progressView;

@end

@implementation RootWindowController

- (instancetype)initWithWindowNibName:(NSNibName)windowNibName {
    self = [super initWithWindowNibName:windowNibName];
    if (nil != self) {
        self->_sidebar = [[SidebarController alloc] initWithNibName:@"SidebarController" bundle:nil];
        self->_itemsDisplay = [[ItemsDisplayController alloc] initWithNibName:@"ItemsDisplayController" bundle:nil];
        self->_details = [[DetailsController alloc] initWithNibName:@"DetailsController" bundle:nil];
        self->_splitViewController = [[NSSplitViewController alloc] init];
        self->_progressView = [[ToolbarProgressView alloc] initWithFrame:NSMakeRect(0.0, 0.0, 250.0, 28.0)];
    }
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];

    NSSplitViewItem *sidebarItem = [NSSplitViewItem sidebarWithViewController:self.sidebar];
    [self.splitViewController addSplitViewItem:sidebarItem];
    sidebarItem.minimumThickness = 100.0;
    sidebarItem.maximumThickness = 250.0;

    NSSplitViewItem *mainItem = [NSSplitViewItem splitViewItemWithViewController:self.itemsDisplay];
    [self.splitViewController addSplitViewItem:mainItem];
    mainItem.minimumThickness = 220.0;

    NSSplitViewItem *detailsItem = [NSSplitViewItem splitViewItemWithViewController:self.details];
    [self.splitViewController addSplitViewItem:detailsItem];
    detailsItem.maximumThickness = 300.0;

    self.contentViewController = self.splitViewController;

    [self.window setFrameUsingName:@"RootWindow"];
    self.windowFrameAutosaveName = @"RootWindow";

    self.itemsDisplay.delegate = self;

    AppDelegate *appDelegate = (AppDelegate*)[NSApplication sharedApplication].delegate;
    LibraryController *library = appDelegate.libraryController;
    library.delegate = self;
}


#pragma mark - LibraryControllerDelegate

- (void)libraryDidUpdate:(NSDictionary *)changeNotificationData {
    dispatch_assert_queue(dispatch_get_main_queue());

    AppDelegate *appDelegate = (AppDelegate*)[NSApplication sharedApplication].delegate;
    NSManagedObjectContext *viewContext = appDelegate.persistentContainer.viewContext;
    [NSManagedObjectContext mergeChangesFromRemoteContextSave:changeNotificationData
                                                 intoContexts:@[viewContext]];

    [self.itemsDisplay reloadData];
}


#pragma mark -

- (void)thumbnailGenerationFailedWithError:(NSError *)error {
    NSAssert(nil != error, @"Thumbnail generation sent nil error");
    NSAlert *alert = [NSAlert alertWithError:error];
    [alert runModal];
}

#pragma mark - ItemDisplayController

- (void)itemsDisplayController:(ItemsDisplayController *)itemDisplayController
            selectionDidChange:(Item *)selectedItem {
    [self.details setItemForDisplay:selectedItem];
}

- (void)itemsDisplayController:(ItemsDisplayController *)itemsDisplayController 
            viewStyleDidChange:(ItemsDisplayStyle)displayStyle {
    dispatch_assert_queue(dispatch_get_main_queue());

    NSToolbar *toolbar = self.window.toolbar;
    if (nil == toolbar) {
        return;
    }
    for (NSToolbarItem *item in toolbar.items) {
        if ([item.itemIdentifier compare: kItemDisplayStyleItemIdentifier] != NSOrderedSame) {
            continue;
        }
        NSAssert([item isKindOfClass: [NSToolbarItemGroup class]], @"Expected this to be a toolbar group item");
        NSToolbarItemGroup *group = (NSToolbarItemGroup *)item;
        [group setSelectedIndex:displayStyle];
        break;
    }
}

- (void)itemsDisplayController:(ItemsDisplayController *)itemsDisplayController 
         didReceiveDroppedURLs:(NSSet<NSURL *> *)URLs {
    dispatch_assert_queue(dispatch_get_main_queue());

    AppDelegate *appDelegate = (AppDelegate*)[NSApplication sharedApplication].delegate;
    LibraryController *library = appDelegate.libraryController;

    // This is async, so returns immediately
    @weakify(self);
    [library importURLs:[URLs allObjects]
               callback:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            @strongify(self);
            if (nil == self) {
                return;
            }

            if (nil != error) {
                NSAssert(NO == success, @"Got error and success from saving.");
                NSAlert *alert = [NSAlert alertWithError:error];
                [alert runModal];
                return;
            }
            NSAssert(NO != success, @"Got no success and error from saving.");
        });
    }];
}

#pragma mark - Custom behaviour

- (IBAction)import:(id)sender {
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = YES;
    panel.canCreateDirectories = NO;
    
    // beginSheetModalForWindow is effectively async on mainQ (the block doesn't have the caller in
    // its stack, so we need to treat it like so and weakify self).
    @weakify(self);
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        @strongify(self);
        if (nil == self) {
            return;
        }
        
        if (NSModalResponseOK == result) {
            NSArray<NSURL *> *urls = [panel URLs];
            
            AppDelegate *appDelegate = (AppDelegate*)[NSApplication sharedApplication].delegate;
            LibraryController *library = appDelegate.libraryController;
            
            // This is async, so returns immediately
            @weakify(self);
            [library importURLs:urls
                       callback:^(BOOL success, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    @strongify(self);
                    if (nil == self) {
                        return;
                    }
                    
                    if (nil != error) {
                        NSAssert(NO == success, @"Got error and success from saving.");
                        NSAlert *alert = [NSAlert alertWithError:error];
                        [alert runModal];
                        return;
                    }
                    NSAssert(NO != success, @"Got no success and error from saving.");
                });
            }];
        }
    }];
}

#pragma mark - Toolbar items

- (IBAction)setViewStyle:(id)sender {
    if (![sender isKindOfClass: [NSToolbarItemGroup class]]) {
        NSAssert(NO, @"Expected toolbaritemgroup, got %@", sender);
    }
    NSToolbarItemGroup *group = (NSToolbarItemGroup *)sender;
    ItemsDisplayStyle style = (ItemsDisplayStyle)[group selectedIndex];
    [self.itemsDisplay setDisplayStyle:style];
}

- (void)toggleSidebar {
    NSSplitViewItem *firstView = self.splitViewController.splitViewItems.firstObject;
    if (nil == firstView) {
        return;
    }
    firstView.collapsed = !firstView.collapsed;
}

- (void)toggleDetails:(id)sender {
    NSSplitViewItem *lastView = self.splitViewController.splitViewItems.lastObject;
    if (nil == lastView) {
        return;
    }
    lastView.collapsed = !lastView.collapsed;
}

- (void)shareItem:(id)sender {
}

- (void)toggleFavourite:(id)sender {
}

- (void)trashItem:(id)sender {
//    if (nil == self.details.item) {
//        return;
//    }
    
}


#pragma mark - NSToolbarDelegate

- (NSArray<NSToolbarIdentifier> *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
    return @[
        NSToolbarFlexibleSpaceItemIdentifier,
        kImportToolbarItemIdentifier,
        NSToolbarSidebarTrackingSeparatorItemIdentifier,
//        kProgressToolbarItemIdentifier,
        NSToolbarFlexibleSpaceItemIdentifier,
        kShareToolbarItemIdentifier,
        kFavouriteToolbarItemIdentifier,
        NSToolbarSpaceItemIdentifier,
        kDeleteToolbarItemIdentifier,
        NSToolbarSpaceItemIdentifier,
        kItemDisplayStyleItemIdentifier,
        NSToolbarSpaceItemIdentifier,
        kToggleDetailViewToolbarItemIdentifier,
        kSearchToolbarItemIdentifier
    ];
}

- (NSArray<NSToolbarIdentifier> *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
    return @[
        kImportToolbarItemIdentifier,
        NSToolbarFlexibleSpaceItemIdentifier,
        kSearchToolbarItemIdentifier,
        kItemDisplayStyleItemIdentifier,
        kShareToolbarItemIdentifier,
        kDeleteToolbarItemIdentifier,
        kFavouriteToolbarItemIdentifier,
    ];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSToolbarItemIdentifier)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag {
    
    if ([itemIdentifier compare:kSearchToolbarItemIdentifier] == NSOrderedSame) {
        return [[NSSearchToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
    } else if ([itemIdentifier compare:kImportToolbarItemIdentifier] == NSOrderedSame) {
        NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
        item.title = @"Import";
        item.paletteLabel = @"Import";
        item.toolTip = @"Import files";
        item.image = [NSImage imageWithSystemSymbolName:@"plus" accessibilityDescription:nil];
        item.target = self;
        item.action = @selector(import:);
        
        return item;
    } else if ([itemIdentifier compare:kProgressToolbarItemIdentifier] == NSOrderedSame) {
        NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
        item.title = @"Progress";
        item.paletteLabel = @"Progress";
        item.toolTip = @"Import progress";
        item.target = self;
        item.action = @selector(import:);
        item.view = self.progressView;

        return item;
    } else if ([itemIdentifier compare:kToggleDetailViewToolbarItemIdentifier] == NSOrderedSame) {
        NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
        item.title = @"Toggle Detail Panel";
        item.paletteLabel = @"Toggle Detail Panel";
        item.toolTip = @"Toggle Detail Panel";
        item.image = [NSImage imageWithSystemSymbolName:@"sidebar.right" accessibilityDescription:nil];
        item.target = self;
        item.action = @selector(toggleDetails:);

        return item;
    } else if ([itemIdentifier compare:kShareToolbarItemIdentifier] == NSOrderedSame) {
        NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
        item.title = @"Share";
        item.paletteLabel = @"Share";
        item.toolTip = @"Share";
        item.image = [NSImage imageWithSystemSymbolName:@"square.and.arrow.up" accessibilityDescription:nil];
        item.target = self;
        item.action = @selector(shareItem:);

        return item;
    } else if ([itemIdentifier compare:kDeleteToolbarItemIdentifier] == NSOrderedSame) {
        NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
        item.title = @"Move To Trash";
        item.paletteLabel = @"Move To Trash";
        item.toolTip = @"Move To Trash";
        item.image = [NSImage imageWithSystemSymbolName:@"trash" accessibilityDescription:nil];
        item.target = self;
        item.action = @selector(trashItem:);

        return item;
    } else if ([itemIdentifier compare:kFavouriteToolbarItemIdentifier] == NSOrderedSame) {
        NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
        item.title = @"Favourite";
        item.paletteLabel = @"Favourite";
        item.toolTip = @"Favourite";
        item.image = [NSImage imageWithSystemSymbolName:@"heart" accessibilityDescription:nil];
        item.target = self;
        item.action = @selector(toggleFavourite:);

        return item;
    } else if ([itemIdentifier compare:kItemDisplayStyleItemIdentifier] == NSOrderedSame) {

        NSArray<NSString *> *titles = @[
            @"Grid",
            @"Single"
        ];

        NSArray<NSImage *> *images = @[
            [NSImage imageWithSystemSymbolName:@"square.grid.2x2" accessibilityDescription:nil],
            [NSImage imageWithSystemSymbolName:@"square" accessibilityDescription:nil]
        ];

        NSToolbarItemGroup *group = [NSToolbarItemGroup groupWithItemIdentifier:itemIdentifier
                                                                         images:images
                                                                  selectionMode:NSToolbarItemGroupSelectionModeSelectOne
                                                                         labels:titles
                                                                         target:self
                                                                         action:@selector(setViewStyle:)];
        group.selectedIndex = self.itemsDisplay.displayStyle;

        return group;
    } else {
        return [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
    }
}


@end
