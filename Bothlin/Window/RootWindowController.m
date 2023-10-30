//
//  RootWindowController.m
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 28/09/2023.
//

#import "RootWindowController.h"
#import "SidebarController.h"
#import "AssetsDisplayController.h"
#import "DetailsController.h"
#import "AppDelegate.h"
#import "LibraryWriteCoordinator.h"
#import "ToolbarProgressView.h"
#import "Helpers.h"
#import "SidebarItem.h"
#import "Group+CoreDataClass.h"
#import "NSArray+Functional.h"
#import "NSSet+Functional.h"
#import "LibraryViewModel.h"
#import "KVOBox.h"
#import "Asset+CoreDataClass.h"

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
@property (nonatomic, strong, readonly) AssetsDisplayController *assetsDisplay;
@property (nonatomic, strong, readonly) DetailsController *details;
@property (nonatomic, strong, readonly) NSSplitViewController *splitViewController;
@property (nonatomic, strong, readonly) ToolbarProgressView *progressView;

@property (nonatomic, strong, readonly) LibraryViewModel *viewModel;

@property (nonatomic, strong, readonly) KVOBox *sidebarObserver;
@property (nonatomic, strong, readonly) KVOBox *assetsObserver;
@property (nonatomic, strong, readonly) KVOBox *selectedObserver;

@end

@implementation RootWindowController

- (instancetype)initWithWindowNibName:(NSNibName)windowNibName
                          viewContext:(NSManagedObjectContext *)viewContext {
    self = [super initWithWindowNibName:windowNibName];
    if (nil != self) {
        self->_sidebar = [[SidebarController alloc] initWithNibName:@"SidebarController" bundle:nil];
        self->_assetsDisplay = [[AssetsDisplayController alloc] initWithNibName:@"AssetsDisplayController" bundle:nil];
        self->_details = [[DetailsController alloc] initWithNibName:@"DetailsController" bundle:nil];
        self->_splitViewController = [[NSSplitViewController alloc] init];
        self->_progressView = [[ToolbarProgressView alloc] initWithFrame:NSMakeRect(0.0, 0.0, 250.0, 28.0)];
        self->_viewModel = [[LibraryViewModel alloc] initWithViewContext:viewContext];

        self->_sidebarObserver = [KVOBox observeObject:self->_viewModel
                                               keyPath:@"sidebarItems"];
        self->_assetsObserver = [KVOBox observeObject:self->_viewModel
                                             keyPath:@"assets"];
        self->_selectedObserver = [KVOBox observeObject:self->_viewModel
                                                keyPath:@"selectedAssetIndexPath"];
    }
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];

    NSSplitViewItem *sidebarItem = [NSSplitViewItem sidebarWithViewController:self.sidebar];
    [self.splitViewController addSplitViewItem:sidebarItem];
    sidebarItem.minimumThickness = 100.0;
    sidebarItem.maximumThickness = 250.0;

    NSSplitViewItem *mainItem = [NSSplitViewItem splitViewItemWithViewController:self.assetsDisplay];
    [self.splitViewController addSplitViewItem:mainItem];
    mainItem.minimumThickness = 220.0;

    NSSplitViewItem *detailsItem = [NSSplitViewItem splitViewItemWithViewController:self.details];
    [self.splitViewController addSplitViewItem:detailsItem];
    detailsItem.maximumThickness = 300.0;

    self.contentViewController = self.splitViewController;

    [self.window setFrameUsingName:@"RootWindow"];
    self.windowFrameAutosaveName = @"RootWindow";

    self.assetsDisplay.delegate = self;
    self.sidebar.delegate = self;

    AppDelegate *appDelegate = (AppDelegate*)[NSApplication sharedApplication].delegate;
    LibraryWriteCoordinator *library = appDelegate.libraryController;
    library.delegate = self.viewModel;

    self.viewModel.delegate = self;

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
        [self updateToolbar];
    }
                                                  error:&error];
    if (nil != error) {
        NSAssert(NO == success, @"Got error and success");
        NSAlert *alert = [NSAlert alertWithError:error];
        [alert runModal];
        return;
    }
    NSAssert(NO != success, @"Got no error and no success");

    success = [self.assetsObserver startWithBlock:^(__unused NSDictionary * _Nonnull changes) {
        @strongify(self);
        if (nil == self) {
            return;
        }
        dispatch_assert_queue(dispatch_get_main_queue());
        [self.assetsDisplay setAssets:self.viewModel.assets
                        withSelected:self.viewModel.selectedAssetIndexPaths];
        [self updateToolbar];

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
        [self.assetsDisplay setAssets:self.viewModel.assets
                         withSelected:self.viewModel.selectedAssetIndexPaths];
        NSSet<Asset *> *selectedAssets = [self.viewModel selectedAssets];
        [self.details setItemForDisplay:[selectedAssets count] == 1 ? [selectedAssets anyObject] : nil];
        [self updateToolbar];
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

- (void)updateToolbar {
    NSArray<NSToolbarItem *> *toolbarItems = [[self.window toolbar] items];
    NSAssert(nil != toolbarItems, @"Toolbar unexpctedly has no items");

    NSSet<NSIndexPath *> *selection = [self.viewModel selectedAssetIndexPaths];
    BOOL isAnyItemSelected = [selection count] > 0;
    BOOL isOneItemSelected = [selection count] == 1;

    // TODO: make this work? But that'd require we not just toggle fave, so whilst
    // I add multiselection support, just stop you changing fave if many things selected
    BOOL isItemFavourite = isOneItemSelected && ([[self.viewModel selectedAssets] anyObject].favourite);

    // TODO: This logic assumes we never mix views of deleted and undeleted items
    BOOL isDeleted = isAnyItemSelected && (nil != [[self.viewModel selectedAssets] anyObject].deletedAt);

    SidebarItemDragResponse sidebarTypeIndicator = [[self.viewModel selectedSidebarItem] dragResponseType];

    for (NSToolbarItem *toolbarItem in toolbarItems) {
        NSToolbarIdentifier identifier = [toolbarItem itemIdentifier];

        if ([identifier compare:kFavouriteToolbarItemIdentifier] == NSOrderedSame) {
            [toolbarItem setEnabled:isOneItemSelected && !isDeleted];
            NSString *symbol = isItemFavourite ? @"heart.fill" : @"heart";
            [toolbarItem setImage:[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:nil]];
        }

        if ([identifier compare:kDeleteToolbarItemIdentifier] == NSOrderedSame) {
            [toolbarItem setEnabled:isAnyItemSelected];
            NSString *symbol = SidebarItemDragResponseGroup == sidebarTypeIndicator ?
                @"folder.badge.minus" :
                (isDeleted ? @"trash.slash" : @"trash");
            [toolbarItem setImage:[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:nil]];
        }

        if ([identifier compare:kShareToolbarItemIdentifier] == NSOrderedSame) {
            [toolbarItem setEnabled:isAnyItemSelected && !isDeleted];
        }

        if ([identifier compare: kItemDisplayStyleItemIdentifier] == NSOrderedSame) {
            NSAssert([toolbarItem isKindOfClass: [NSToolbarItemGroup class]], @"Expected this to be a toolbar group item");
            NSToolbarItemGroup *group = (NSToolbarItemGroup *)toolbarItem;
            [group setSelectedIndex:self.assetsDisplay.displayStyle];
            [group setEnabled:isOneItemSelected];
        }
    }
}

#pragma mark - State logic
// State logic is mostly a thin wrapper onto LibraryWriteCoordinator, which should do the actual work
// but we need to do some wrapping here, because we need to work with the undo manager which is tried
// to NSWindow and we're the window controller. It also removes duplication when there are multiple UI
// paths to the same action

- (void)setFavouriteStateOnAssets:(NSSet<NSManagedObjectID *> *)assetIDs
                         newState:(BOOL)state
                    userInitiated:(BOOL)userInitiated {
    NSParameterAssert(nil != assetIDs);
    dispatch_assert_queue(dispatch_get_main_queue());

    AppDelegate *appDelegate = (AppDelegate*)[NSApplication sharedApplication].delegate;
    LibraryWriteCoordinator *library = appDelegate.libraryController;

    @weakify(self);
    [library setFavouriteStateOnAssets:assetIDs
                              newState:state
                         callback:^(BOOL success, NSError * _Nonnull error, BOOL newState) {
        if (nil != error) {
            NSAssert(NO == success, @"Got error and success!");
            dispatch_async(dispatch_get_main_queue(), ^{
                NSAlert *alert = [NSAlert alertWithError:error];
                [alert runModal];
            });
        }
        NSAssert(NO != success, @"Got no error and not success!");

        if (userInitiated) {
            dispatch_async(dispatch_get_main_queue(), ^{

                NSUndoManager *undoManager = [self.window undoManager];
                [undoManager registerUndoWithTarget:assetIDs
                                            handler:^(NSSet<NSManagedObjectID *> * _Nonnull target) {
                    @strongify(self);
                    if (nil == self) {
                        return;
                    }
                    // TODO: This is broken, as there's not guarantee the original assets were all
                    // of the opposite state, but this is a bodge as I added this whilst
                    // replumbing everyting from single selection to many. Must go back and fix all
                    // this after.
                    [self setFavouriteStateOnAssets:target
                                           newState:!state
                                      userInitiated:NO];
                }];
                [undoManager setActionName:newState ? @"Set Favourite" : @"Remove Favourite"];
            });
        }
    }];
}

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

        NSManagedObjectID *relatedObject = [self.viewModel selectedSidebarItem].relatedOject;

        if (NSModalResponseOK == result) {
            NSArray<NSURL *> *urls = [panel URLs];

            AppDelegate *appDelegate = (AppDelegate*)[NSApplication sharedApplication].delegate;
            LibraryWriteCoordinator *library = appDelegate.libraryController;

            // This is async, so returns immediately
            @weakify(self);
            [library importURLs:urls
                        toGroup:relatedObject
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


#pragma mark - LibraryViewModelDelegate

- (void)libraryViewModel:(LibraryViewModel *)libraryViewModel hadErrorOnUpdate:(NSError *)error {
    NSParameterAssert(nil != error);
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert *alert = [NSAlert alertWithError:error];
        [alert runModal];
    });
}


#pragma mark - SidebarControllerDelegate

- (void)addGroupViaSidebarController:(__unused SidebarController *)sidebarController {
    [self showGroupCreatePanel:sidebarController];
}

- (void)sidebarController:(__unused SidebarController *)sidebarController didChangeSelectedOption:(SidebarItem *)sidebarItem {
    [self.viewModel setSelectedSidebarItem:sidebarItem];
}

- (BOOL)sidebarController:(__unused SidebarController *)sidebearController
       recievedIndexPaths:(NSSet<NSIndexPath *> *)indexPathSet
                   onItem:(SidebarItem *)sidebarItem {
    dispatch_assert_queue(dispatch_get_main_queue());
    NSParameterAssert(nil != indexPathSet);
    NSParameterAssert(nil != sidebarItem);

    if ([indexPathSet count] == 0) {
        return NO;
    }

    NSArray<Asset *> *allAssets = self.viewModel.assets;
    NSSet<Asset *> *assets = [indexPathSet compactMapUsingBlock:^id _Nullable(NSIndexPath * _Nonnull object) {
        NSInteger index = [object item];
        if ((NSNotFound == index) || (0 > index) || ([allAssets count] < index)) {
            return nil;
        }
        return [allAssets objectAtIndex:(NSUInteger)index];
    }];

    AppDelegate *appDelegate = (AppDelegate*)[NSApplication sharedApplication].delegate;
    LibraryWriteCoordinator *library = appDelegate.libraryController;

    BOOL accepted = NO;
    switch (sidebarItem.dragResponseType) {
        case SidebarItemDragResponseGroup:
            if (nil != sidebarItem.relatedOject) {
                [library addAssets:[assets mapUsingBlock:^id _Nonnull(Asset * _Nonnull asset) { return asset.objectID; }]
                           toGroup:sidebarItem.relatedOject
                          callback:^(BOOL success, NSError * _Nonnull error) {
                    if (nil != error) {
                        NSAssert(NO == success, @"Got error and success");
                        dispatch_async(dispatch_get_main_queue(), ^{
                            NSAlert *alert = [NSAlert alertWithError:error];
                            [alert runModal];
                        });
                    }
                    NSAssert(NO != success, @"got no error and no success");
                }];
            }
            accepted = YES;
            break;
        case SidebarItemDragResponseTrash: {
            [library toggleSoftDeleteAssets:[assets mapUsingBlock:^id _Nonnull(Asset * _Nonnull asset) { return asset.objectID; }]
                                   callback:^(BOOL success, NSError * _Nonnull error) {
                if (nil != error) {
                    NSAssert(NO == success, @"Got error and success");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        NSAlert *alert = [NSAlert alertWithError:error];
                        [alert runModal];
                    });
                }
                NSAssert(NO != success, @"got no error and no success");
            }];
            accepted = YES;
        }
            break;
        case SidebarItemDragResponseFavourite: {
            // In a mixed set, only toggle those that are not currently favourited
            NSSet<Asset *> *notFavourited = [assets compactMapUsingBlock:^id _Nonnull(Asset * _Nonnull asset) {
                return asset.favourite ? nil : asset;
            }];

            if (0 < [notFavourited count]) {
                [self setFavouriteStateOnAssets:[assets mapUsingBlock:^id _Nonnull(Asset * _Nonnull asset) { return asset.objectID; }]
                                       newState:![assets anyObject].favourite
                                  userInitiated:YES];
            }
            accepted = YES;
        }
            break;
        default:
            break;
    }
    return accepted;
}


#pragma mark - AssetsDisplayControllerDelegate

- (void)assetsDisplayController:(__unused AssetsDisplayController *)assetDisplayController
             selectionDidChange:(NSSet<NSIndexPath *> *)selectedIndexPaths {
    [self.viewModel setSelectedAssetIndexPaths:selectedIndexPaths];
}

- (void)assetsDisplayController:(__unused AssetsDisplayController *)assetsDisplayController
            viewStyleDidChange:(__unused ItemsDisplayStyle)displayStyle {
    dispatch_assert_queue(dispatch_get_main_queue());
    [self updateToolbar];
}

- (BOOL)assetsDisplayController:(__unused AssetsDisplayController *)assetsDisplayController
          didReceiveDroppedURLs:(NSSet<NSURL *> *)URLs {
    dispatch_assert_queue(dispatch_get_main_queue());

    // Don't allow drag onto certain things:
    SidebarItemDragResponse sidebarItemType = [self.viewModel selectedSidebarItem].dragResponseType;
    if (SidebarItemDragResponseTrash == sidebarItemType) {
        return NO;
    }

    AppDelegate *appDelegate = (AppDelegate*)[NSApplication sharedApplication].delegate;
    LibraryWriteCoordinator *library = appDelegate.libraryController;

    NSManagedObjectID *relatedObject = [self.viewModel selectedSidebarItem].relatedOject;

    // This is async, so returns immediately
    @weakify(self);
    [library importURLs:[URLs allObjects]
                toGroup:relatedObject
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

    return YES;
}

- (BOOL)assetsDisplayController:(__unused AssetsDisplayController *)assetsDisplayController
                         assets:(NSSet<Asset *> *)assets
        wasDraggedOnSidebarItem:(SidebarItem *)sidebarItem {
    NSParameterAssert(nil != assets);
    NSParameterAssert(nil != sidebarItem);

    AppDelegate *appDelegate = (AppDelegate*)[NSApplication sharedApplication].delegate;
    LibraryWriteCoordinator *library = appDelegate.libraryController;

    BOOL accepted = NO;
    switch (sidebarItem.dragResponseType) {
        case SidebarItemDragResponseGroup:
            if (nil != sidebarItem.relatedOject) {
                [library addAssets:[assets mapUsingBlock:^id _Nonnull(Asset * _Nonnull asset) { return asset.objectID; }]
                          toGroup:sidebarItem.relatedOject
                         callback:^(BOOL success, NSError * _Nonnull error) {
                    if (nil != error) {
                        NSAssert(NO == success, @"Got error and success");
                        dispatch_async(dispatch_get_main_queue(), ^{
                            NSAlert *alert = [NSAlert alertWithError:error];
                            [alert runModal];
                        });
                    }
                    NSAssert(NO != success, @"got no error and no success");
                }];
            }
            accepted = YES;
            break;
        case SidebarItemDragResponseTrash: {
                [library toggleSoftDeleteAssets:[assets mapUsingBlock:^id _Nonnull(Asset * _Nonnull asset) { return asset.objectID; }]
                                       callback:^(BOOL success, NSError * _Nonnull error) {
                    if (nil != error) {
                        NSAssert(NO == success, @"Got error and success");
                        dispatch_async(dispatch_get_main_queue(), ^{
                            NSAlert *alert = [NSAlert alertWithError:error];
                            [alert runModal];
                        });
                    }
                    NSAssert(NO != success, @"got no error and no success");
                }];
                accepted = YES;
            }
            break;
        case SidebarItemDragResponseFavourite: {
                // In a mixed set, only toggle those that are not currently favourited
                NSSet<Asset *> *notFavourited = [assets compactMapUsingBlock:^id _Nonnull(Asset * _Nonnull asset) {
                    return asset.favourite ? nil : asset;
                }];

                if (0 < [notFavourited count]) {
                    [self setFavouriteStateOnAssets:[assets mapUsingBlock:^id _Nonnull(Asset * _Nonnull asset) { return asset.objectID; }]
                                           newState:![assets anyObject].favourite
                                      userInitiated:YES];
                }
                accepted = YES;
            }
            break;
        default:
            break;
    }
    return accepted;
}

- (void)assetsDisplayController:(__unused AssetsDisplayController *)assetsDisplayController
           failedToDisplayAsset:(__unused Asset *)asset
                          error:(NSError *)error {
    dispatch_assert_queue(dispatch_get_main_queue());
    NSAlert *alert = [NSAlert alertWithError:error];
    [alert runModal];
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
    LibraryWriteCoordinator *library = appDelegate.libraryController;
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
    [self.assetsDisplay setDisplayStyle:style];
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
    // TODO: UI should be set to only allow this when a single item is selected, we should do
    // better one day
    Asset *selectedAsset = [self.viewModel.selectedAssets anyObject];
    if (nil == selectedAsset) {
        return;
    }
    [self setFavouriteStateOnAssets:[NSSet setWithObject:selectedAsset]
                           newState:!selectedAsset.favourite
                      userInitiated:YES];
}

- (void)trashItem:(id)sender {
    NSSet<Asset *> *selectedAssets = self.viewModel.selectedAssets;
    if (0 == [selectedAssets count]) {
        return;
    }
    
    AppDelegate *appDelegate = (AppDelegate*)[NSApplication sharedApplication].delegate;
    LibraryWriteCoordinator *library = appDelegate.libraryController;
    
    SidebarItem *selectedSidebarItem = [self.viewModel selectedSidebarItem];
    if (SidebarItemDragResponseGroup == selectedSidebarItem.dragResponseType) {
        // In a group, so remove assets from group rather than delete
        NSManagedObjectID *groupID = selectedSidebarItem.relatedOject;
        [library removeAssets:[selectedAssets mapUsingBlock:^id _Nonnull(Asset * _Nonnull asset) { return asset.objectID; }]
                    fromGroup:groupID
                     callback:^(BOOL success, NSError * _Nonnull error) {
            if (nil != error) {
                NSAssert(NO == success, @"Got error and success!");
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSAlert *alert = [NSAlert alertWithError:error];
                    [alert runModal];
                });
            }
            NSAssert(NO != success, @"Got no error and not success!");
        }];
    } else {
        // Toggle whether in trash
        [library toggleSoftDeleteAssets:[selectedAssets mapUsingBlock:^id _Nonnull(Asset * _Nonnull asset) { return asset.objectID; }]
                               callback:^(BOOL success, NSError * _Nonnull error) {
            if (nil != error) {
                NSAssert(NO == success, @"Got error and success!");
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSAlert *alert = [NSAlert alertWithError:error];
                    [alert runModal];
                });
            }
            NSAssert(NO != success, @"Got no error and not success!");
        }];
    }
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
        item.autovalidates = NO;
        item.enabled = [[self.viewModel selectedAssetIndexPaths] count] > 0;
        
        return item;
    } else if ([itemIdentifier compare:kDeleteToolbarItemIdentifier] == NSOrderedSame) {
        NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
        item.title = @"Move To Trash";
        item.paletteLabel = @"Move To Trash";
        item.toolTip = @"Move To Trash";
        item.image = [NSImage imageWithSystemSymbolName:@"trash" accessibilityDescription:nil];
        item.target = self;
        item.action = @selector(trashItem:);
        item.autovalidates = NO;
        item.enabled = [[self.viewModel selectedAssetIndexPaths] count] > 0;
        
        return item;
    } else if ([itemIdentifier compare:kFavouriteToolbarItemIdentifier] == NSOrderedSame) {
        NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
        item.title = @"Favourite";
        item.paletteLabel = @"Favourite";
        item.toolTip = @"Favourite";
        NSString *symbol = ([[self.viewModel selectedAssetIndexPaths] count] == 1) && ([self.viewModel.selectedAssets anyObject].favourite) ? @"heart.fill" : @"heart";
        item.image = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:nil];
        item.target = self;
        item.action = @selector(toggleFavourite:);
        item.autovalidates = NO;
        item.enabled = [[self.viewModel selectedAssetIndexPaths] count] == 1;
        
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
        group.selectedIndex = self.assetsDisplay.displayStyle;
        
        return group;
    } else {
        return [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
    }
}

@end
