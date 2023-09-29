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

NSString * __nonnull const kImportToolbarItemIdentifier = @"ImportToolbarItemIdentifier";
NSString * __nonnull const kSearchToolbarItemIdentifier = @"SearchToolbarItemIdentifier";
NSString * __nonnull const kProgressToolbarItemIdentifier = @"ProgressToolbarItemIdentifier";

@interface RootWindowController ()

@property (nonatomic, strong, readonly) SidebarController *sidebar;
@property (nonatomic, strong, readonly) ItemsDisplayController *itemsDisplay;
@property (nonatomic, strong, readonly) DetailsController *details;
@property (nonatomic, strong, readonly) NSSplitViewController *splitViewController;
@property (nonatomic, strong, readonly) ToolbarProgressView *progressView;

@end

@implementation RootWindowController

- (instancetype)initWithWindowNibName:(NSNibName)windowNibName {
    self = [super initWithWindowNibName: windowNibName];
    if (nil != self) {
        self->_sidebar = [[SidebarController alloc] initWithNibName: @"SidebarController" bundle: nil];
        self->_itemsDisplay = [[ItemsDisplayController alloc] initWithNibName: @"ItemsDisplayController" bundle: nil];
        self->_details = [[DetailsController alloc] initWithNibName: @"DetailsController" bundle: nil];
        self->_splitViewController = [[NSSplitViewController alloc] init];
        self->_progressView = [[ToolbarProgressView alloc] initWithFrame: NSMakeRect(0.0, 0.0, 250.0, 28.0)];
    }
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    NSSplitViewItem *sidebarItem = [NSSplitViewItem sidebarWithViewController: self.sidebar];
    [self.splitViewController addSplitViewItem: sidebarItem];
    sidebarItem.minimumThickness = 100.0;
    sidebarItem.maximumThickness = 250.0;

    NSSplitViewItem *mainItem = [NSSplitViewItem splitViewItemWithViewController: self.itemsDisplay];
    [self.splitViewController addSplitViewItem: mainItem];
    mainItem.minimumThickness = 220.0;

    NSSplitViewItem *detailsItem = [NSSplitViewItem splitViewItemWithViewController: self.details];
    [self.splitViewController addSplitViewItem: detailsItem];
    detailsItem.maximumThickness = 220.0;

    self.contentViewController = self.splitViewController;

    [self.window setFrameUsingName: @"RootWindow"];
    self.windowFrameAutosaveName = @"RootWindow";
}


#pragma mark - Custom behaviour

- (IBAction)import: (id)sender {
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = YES;
    panel.canCreateDirectories = NO;

    [panel beginSheetModalForWindow: self.window completionHandler: ^(NSInteger result) {
        if (NSModalResponseOK == result) {
            NSArray<NSURL *> *urls = [panel URLs];

            AppDelegate *appDelegate = (AppDelegate*)[NSApplication sharedApplication].delegate;
            LibraryController *library = appDelegate.libraryController;

            // This is async, so returns immediately
            __weak typeof(self) weakSelf = self;
            [library importURLs: urls
                       callback: ^(BOOL success, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    __strong typeof(self) strongSelf = weakSelf;
                    if (nil == strongSelf) {
                        return;
                    }

                    if (nil != error) {
                        NSAssert(NO == success, @"Got error and success from saving.");
                        NSAlert *alert = [NSAlert alertWithError: error];
                        [alert runModal];
                    }
                    NSAssert(YES == success, @"Got no success and error from saving.");

                    [strongSelf.itemsDisplay reloadData];
                });
            }];
        }
    }];
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
    return [NSArray arrayWithObjects:
            NSToolbarFlexibleSpaceItemIdentifier,
            kImportToolbarItemIdentifier,
            NSToolbarSidebarTrackingSeparatorItemIdentifier,
            kProgressToolbarItemIdentifier,
            NSToolbarFlexibleSpaceItemIdentifier,
            kSearchToolbarItemIdentifier,
            nil];
}

- (NSArray<NSToolbarIdentifier> *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
    return [NSArray arrayWithObjects:
            kImportToolbarItemIdentifier,
            NSToolbarFlexibleSpaceItemIdentifier,
            kSearchToolbarItemIdentifier,
            nil];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSToolbarItemIdentifier)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag {

    if ([itemIdentifier compare: kSearchToolbarItemIdentifier] == NSOrderedSame) {
        return [[NSSearchToolbarItem alloc] initWithItemIdentifier: itemIdentifier];
    } else if ([itemIdentifier compare: kImportToolbarItemIdentifier] == NSOrderedSame) {
        NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier: itemIdentifier];
        item.title = @"Import";
        item.paletteLabel = @"Import";
        item.toolTip = @"Import files";
        item.image = [NSImage imageWithSystemSymbolName: @"plus" accessibilityDescription: nil];
        item.target = self;
        item.action = @selector(import:);

        NSMenuItem *menu = [[NSMenuItem alloc] init];
        menu.submenu = nil;
        menu.title = @"import";
        item.menuFormRepresentation = menu;

        return item;
    } else if ([itemIdentifier compare: kProgressToolbarItemIdentifier] == NSOrderedSame) {
        NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier: itemIdentifier];
        item.title = @"Progress";
        item.paletteLabel = @"Progress";
        item.toolTip = @"Import progress";
        item.target = self;
        item.action = @selector(import:);
        item.view = self.progressView;

        NSMenuItem *menu = [[NSMenuItem alloc] init];
        menu.submenu = nil;
        menu.title = @"progress";
        item.menuFormRepresentation = menu;

        return item;
    } else {
        return [[NSToolbarItem alloc] initWithItemIdentifier: itemIdentifier];
    }
}

@end
