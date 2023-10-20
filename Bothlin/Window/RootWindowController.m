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
#import "SidebarItem.h"
#import "Group+CoreDataClass.h"
#import "NSArray+Functional.h"
#import "LibraryViewModel.h"
#import "KVOBox.h"

NSString * __nonnull const kImportToolbarItemIdentifier = @"ImportToolbarItemIdentifier";
NSString * __nonnull const kSearchToolbarItemIdentifier = @"SearchToolbarItemIdentifier";
NSString * __nonnull const kProgressToolbarItemIdentifier = @"ProgressToolbarItemIdentifier";
NSString * __nonnull const kItemDisplayStyleItemIdentifier = @"ItemDisplayStyleItemIdentifier";
NSString * __nonnull const kShareToolbarItemIdentifier = @"ShareToolbarItemIdentifier";
NSString * __nonnull const kDeleteToolbarItemIdentifier = @"DeleteToolbarItemIdentifier";
NSString * __nonnull const kToggleSidebarToolbarItemIdentifier = @"ToggleSidebarToolbarItemIdentifier";
NSString * __nonnull const kToggleDetailViewToolbarItemIdentifier = @"ToggleDetailViewToolbarItemIdentifier";
NSString * __nonnull const kFavouriteToolbarItemIdentifier = @"FavouriteToolbarItemIdentifier";

@interface RootWindowController ()

@property (nonatomic, strong, readonly) SidebarController *sidebar;
@property (nonatomic, strong, readonly) ItemsDisplayController *itemsDisplay;
@property (nonatomic, strong, readonly) DetailsController *details;
@property (nonatomic, strong, readonly) NSSplitViewController *splitViewController;
@property (nonatomic, strong, readonly) ToolbarProgressView *progressView;

@property (nonatomic, strong, readonly) LibraryViewModel *viewModel;

@property (nonatomic, strong, readonly) KVOBox *sidebarObserver;
@property (nonatomic, strong, readonly) KVOBox *itemsObserver;
@property (nonatomic, strong, readonly) KVOBox *selectedObserver;

@end

@implementation RootWindowController

- (instancetype)initWithWindowNibName:(NSNibName)windowNibName
                          viewContext:(NSManagedObjectContext *)viewContext {
    self = [super initWithWindowNibName:windowNibName];
    if (nil != self) {
        self->_sidebar = [[SidebarController alloc] initWithNibName:@"SidebarController" bundle:nil];
        self->_itemsDisplay = [[ItemsDisplayController alloc] initWithNibName:@"ItemsDisplayController" bundle:nil];
        self->_details = [[DetailsController alloc] initWithNibName:@"DetailsController" bundle:nil];
        self->_splitViewController = [[NSSplitViewController alloc] init];
        self->_progressView = [[ToolbarProgressView alloc] initWithFrame:NSMakeRect(0.0, 0.0, 250.0, 28.0)];
        self->_viewModel = [[LibraryViewModel alloc] initWithViewContext:viewContext];

        self->_sidebarObserver = [KVOBox observeObject:self->_viewModel
                                               keyPath:@"sidebarItems"];
        self->_itemsObserver = [KVOBox observeObject:self->_viewModel
                                             keyPath:@"contents"];
        self->_selectedObserver = [KVOBox observeObject:self->_viewModel
                                                keyPath:@"selected"];
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
    self.sidebar.delegate = self;

    AppDelegate *appDelegate = (AppDelegate*)[NSApplication sharedApplication].delegate;
    LibraryController *library = appDelegate.libraryController;
    library.delegate = self.viewModel;

    // TODO: This whole section is horribly verbose and thus confusing to read. The root
    // cause is that starting a block based observer can fail if the block was already
    // started. I suspect I should just assert in the handler and not ignore the error
    // - it's not like I can recover from this.
    NSError *error = nil;
    @weakify(self);
    BOOL success = [self.sidebarObserver startWithBlock:^(__unused NSDictionary * _Nonnull changes) {
        @strongify(self);
        if (nil == self) {
            return;
        }
        dispatch_assert_queue(dispatch_get_main_queue());
        [self.sidebar setSidebarTree:self.viewModel.sidebarItems];
    } 
                                                  error:&error];
    if (nil != error) {
        NSAssert(NO == success, @"Got error and success");
        NSAlert *alert = [NSAlert alertWithError:error];
        [alert runModal];
        return;
    }
    NSAssert(NO != success, @"Got no error and no success");

    success = [self.itemsObserver startWithBlock:^(__unused NSDictionary * _Nonnull changes) {
        @strongify(self);
        if (nil == self) {
            return;
        }
        dispatch_assert_queue(dispatch_get_main_queue());
        [self.itemsDisplay setItems:self.viewModel.contents
                       withSelected:self.viewModel.selected];

    }
                                                error:&error];
    if (nil != error) {
        NSAssert(NO == success, @"Got error and success");
        NSAlert *alert = [NSAlert alertWithError:error];
        [alert runModal];
        return;
    }
    NSAssert(NO != success, @"Got no error and no success");

    success = [self.selectedObserver startWithBlock:^(__unused NSDictionary * _Nonnull changes) {
        @strongify(self);
        if (nil == self) {
            return;
        }
        dispatch_assert_queue(dispatch_get_main_queue());
        [self.itemsDisplay setItems:self.viewModel.contents
                       withSelected:self.viewModel.selected];
        [self.details setItemForDisplay:self.viewModel.selected];
    }
                                                error:&error];
    if (nil != error) {
        NSAssert(NO == success, @"Got error and success");
        NSAlert *alert = [NSAlert alertWithError:error];
        [alert runModal];
        return;
    }
    NSAssert(NO != success, @"Got no error and no success");

    // Trigger a loading of the groups for the sidebar
    success = [self.viewModel reloadGroups:&error];
    if (nil != error) {
        NSAssert(NO == success, @"Got error and success");
        NSAlert *alert = [NSAlert alertWithError:error];
        [alert runModal];
        return;
    }
    NSAssert(NO != success, @"Got no error and no success");
}


#pragma mark - SidebarControllerDelegate

- (void)addGroupViaSidebarController:(SidebarController *)sidebarController {
    [self showGroupCreatePanel:sidebarController];
}

- (void)sidebarController:(SidebarController *)sidebarController didChangeSelectedOption:(NSFetchRequest *)fetchRequest {
    NSError *error = nil;
    BOOL success = [self.viewModel reloadItemsWithFetchRequest:fetchRequest
                                                         error:&error];
    if (nil != error) {
        NSAssert(NO == success, @"Got error and success");
        NSAlert *alert = [NSAlert alertWithError:error];
        [alert runModal];
        return;
    }
    NSAssert(NO != success, @"Got no error and no success");
}

#pragma mark - ItemDisplayController

- (void)itemsDisplayController:(ItemsDisplayController *)itemDisplayController
            selectionDidChange:(Item *)selectedItem {
    [self.viewModel setSelected:selectedItem];
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

- (BOOL)itemsDisplayController:(ItemsDisplayController *)itemsDisplayController 
                          item:(Item *)item
       wasDraggedOnSidebarItem:(SidebarItem *)sidebarItem {
    NSParameterAssert(nil != item);
    NSParameterAssert(nil != sidebarItem);

    BOOL accepted = NO;
    switch (sidebarItem.dragResponseType) {
        case SidebarItemDragResponseGroup:
            break;
        case SidebarItemDragResponseTrash:
            break;
        case SidebarItemDragResponseFavourite:
            break;
        default:
            break;
    }
    return accepted;
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

#pragma mark - Group creation panel

- (IBAction)showGroupCreatePanel:(id)sender {
    AppDelegate *appDelegate = (AppDelegate*)[NSApplication sharedApplication].delegate;
    NSManagedObjectContext *context = appDelegate.persistentContainer.viewContext;
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"Group"];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name like[c] %@", @"Untitled*"];
    [fetchRequest setPredicate: predicate];
    NSError *error = nil;
    NSArray *groups = [context executeFetchRequest:fetchRequest
                                             error:&error];
    if (nil != error) {
        NSAssert(nil == groups, @"Got error and data");
        NSLog(@"Failed to find untitled groups: %@", error);
    } else {
        NSAssert(nil != groups, @"Got no error and no data");
        NSArray<NSString *> *names = [groups mapUsingBlock:^NSString * _Nonnull(Group * _Nonnull group) {
            return group.name;
        }];
        for (NSUInteger counter = 0; counter < NSUIntegerMax; counter++) {
            NSString *nameSuggestion = counter > 0 ? [NSString stringWithFormat:@"Untitled %lu", counter] : @"Untitled";
            if (NSNotFound == [names indexOfObject:nameSuggestion]) {
                [self.groupCreateNameField setStringValue:nameSuggestion];
                break;
            }
        }
    }

    [self.window beginSheet:self.groupCreatePanel
          completionHandler:^(__unused NSModalResponse returnCode) {
    }];
}

- (IBAction)groupCreateOK:(id)sender {
    NSString *name = [self.groupCreateNameField stringValue];
    AppDelegate *appDelegate = (AppDelegate*)[NSApplication sharedApplication].delegate;
    LibraryController *library = appDelegate.libraryController;
    @weakify(self)
    [library createGroup:name
                callback:^(__unused BOOL success, NSError * _Nullable error) {
        @strongify(self);
        if (nil == self) {
            return;
        }

        @weakify(self);
        dispatch_async(dispatch_get_main_queue(), ^{
            @strongify(self);
            if (nil == self) {
                return;
            }
            if (nil != error) {
                NSAlert *alert = [NSAlert alertWithError:error];
                [alert runModal];
            } else {
                [self.window endSheet:self.groupCreatePanel];
                [self.sidebar expandGroupsBranch];
            }
        });
    }];
}

- (IBAction)groupCreateCancel:(id)sender {
    [self.window endSheet:self.groupCreatePanel];
}

- (void)controlTextDidChange:(NSNotification *)obj {
    NSString *current = [self.groupCreateNameField stringValue];
    BOOL canOkay = [current length] > 0;
    if (canOkay) {
        AppDelegate *appDelegate = (AppDelegate*)[NSApplication sharedApplication].delegate;
        NSManagedObjectContext *context = appDelegate.persistentContainer.viewContext;
        NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"Group"];
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name like[c] %@", current];
        [fetchRequest setPredicate: predicate];

        NSError *error = nil;
        NSArray *groups = [context executeFetchRequest:fetchRequest
                                                 error:&error];
        if (nil != error) {
            NSAssert(nil == groups, @"Got error and result");
            NSLog(@"Failed to look up existing groups");
        } else {
            NSAssert(nil != groups, @"Go no error and no result");
            canOkay = [groups count] == 0;
            [self.groupCreateDuplicateWarningLabel setHidden:canOkay];
        }
    }
    [self.groupCreateOKButton setEnabled: canOkay];
}

- (IBAction)groupNameFieldEnter:(id)sender {
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

- (void)toggleSidebar: (id)sender {
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
        kToggleSidebarToolbarItemIdentifier,
        NSToolbarFlexibleSpaceItemIdentifier,
        kImportToolbarItemIdentifier,
        NSToolbarSidebarTrackingSeparatorItemIdentifier,
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
    } else if ([itemIdentifier compare:kToggleSidebarToolbarItemIdentifier] == NSOrderedSame) {
        NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
        item.title = @"Toggle Group Panel";
        item.paletteLabel = @"Toggle Group Panel";
        item.toolTip = @"Toggle Group Panel";
        item.image = [NSImage imageWithSystemSymbolName:@"sidebar.left" accessibilityDescription:nil];
        item.target = self;
        item.action = @selector(toggleSidebar:);

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
