//
//  RootWindowController.m
//  Bothlin
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

    self.itemsDisplay.gridViewController.delegate = self;

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

- (void)thumbnailGenerationFailedWithError:(NSError *)error {
    NSAssert(nil != error, @"Thumbnail generation sent nil error");
    NSAlert *alert = [NSAlert alertWithError:error];
    [alert runModal];
}

#pragma mark - GridViewControllerDelegate

- (void)gridViewController:(GridViewController *)gridViewController
        selectionDidChange:(Item *)item {
    [self.details setItemForDisplay:item];
}

- (void)gridViewController:(nonnull GridViewController *)gridViewController 
         doubleClickedItem:(nonnull Item *)item {
    
}


#pragma mark - Custom behaviour

- (IBAction)import:(id)sender {
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = YES;
    panel.canCreateDirectories = NO;
    
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
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
                    }
                    NSAssert(NO != success, @"Got no success and error from saving.");
                });
            }];
        }
    }];
}

- (IBAction)toggleViewStyle:(id)sender {

}

- (void)toggleSidebar {
    NSSplitViewItem *firstView = self.splitViewController.splitViewItems.firstObject;
    if (nil == firstView) {
        return;
    }
    firstView.collapsed = !firstView.collapsed;
}

- (void)toggleDetails {
    NSSplitViewItem *lastView = self.splitViewController.splitViewItems.lastObject;
    if (nil == lastView) {
        return;
    }
    lastView.collapsed = !lastView.collapsed;
}


#pragma mark - NSToolbarDelegate

- (NSArray<NSToolbarIdentifier> *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
    return @[
        NSToolbarFlexibleSpaceItemIdentifier,
        kImportToolbarItemIdentifier,
        NSToolbarSidebarTrackingSeparatorItemIdentifier,
//        kProgressToolbarItemIdentifier,
        NSToolbarFlexibleSpaceItemIdentifier,
        kItemDisplayStyleItemIdentifier,
        kSearchToolbarItemIdentifier
    ];
}

- (NSArray<NSToolbarIdentifier> *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
    return @[
        kImportToolbarItemIdentifier,
        NSToolbarFlexibleSpaceItemIdentifier,
        kSearchToolbarItemIdentifier,
        kItemDisplayStyleItemIdentifier,
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
                                                                         action:@selector(toggleViewStyle:)];
        group.selectedIndex = 0;

        return group;
    } else {
        return [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
    }
}


@end
