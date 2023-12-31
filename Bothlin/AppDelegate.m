//
//  AppDelegate.m
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 16/09/2023.
//

#import "AppDelegate.h"
#import "LibraryWriteCoordinator.h"
#import "RootWindowController.h"
#import "SettingsWindowController.h"
#import "ImportCoordinator.h"
#import "Helpers.h"

NSString * __nonnull const kUserDefaultsUsingDefaultStorage = @"kUserDefaultsUsingDefaultStorage";
NSString * __nonnull const kUserDefaultsDefaultStoragePath = @"kUserDefaultsDefaultStoragePath";
NSString * __nonnull const kUserDefaultsCustomStoragePath = @"kUserDefaultsCustomStoragePath";
NSString * __nonnull const kUserDefaultsExpandedSidebarItems = @"kUserDefaultsExpandedSidebarItems";

@interface AppDelegate ()

// mainQ only stuff
@property (nonatomic, strong, readwrite) NSString *trashDisplayName;
@property (nonatomic, strong, readwrite) RootWindowController *mainWindowController;
@property (nonatomic, strong, readwrite) SettingsWindowController *settingsWindowController;
@property (nonatomic, strong, readwrite) NSTimer *launchTaskTimer;

@end

@implementation AppDelegate

+ (void)makeInitialDefaults {
    NSFileManager *fm = [NSFileManager defaultManager];

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSAssert(0 < [paths count], @"Expected at least one documents folder, got none");
    NSString *documentsDirectory = paths.firstObject;
    NSString *defaultStorageFolderPath = [documentsDirectory stringByAppendingPathComponent:@"Screenshots"];
    NSURL *defaultStorageURL = [NSURL fileURLWithPath:defaultStorageFolderPath];

    NSError *error = nil;
    BOOL success = [fm createDirectoryAtURL:defaultStorageURL
                withIntermediateDirectories:YES
                                 attributes:nil
                                      error:&error];
    if (nil != error) {
        NSAssert(NO == success, @"got error creating directory but still success");
        NSLog(@"Failed to create directory: %@", error);
        return;
    }
    NSAssert(NO != success, @"got no error creating directory but still not a success");

    NSData *defaultStorageData = [defaultStorageURL bookmarkDataWithOptions:NSURLBookmarkCreationSecurityScopeAllowOnlyReadAccess
                                             includingResourceValuesForKeys:nil
                                                              relativeToURL:nil
                                                                      error:&error];
    if (nil != error) {
        NSLog(@"Failed to generate default bookmark URL: %@", error);
        return;
    }

    NSDictionary<NSString *, id> *initialDefaultValues = @{
        kUserDefaultsUsingDefaultStorage: @(YES),
        kUserDefaultsDefaultStoragePath: defaultStorageData,
        kUserDefaultsExpandedSidebarItems: @[],
    };

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults registerDefaults:initialDefaultValues];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    if (NO == [self.mainWindowController.window isVisible]) {
        [self.mainWindowController showWindow:nil];
    }
}

- (void)applicationDidFinishLaunching:(NSNotification * _Nonnull)aNotification {
    [AppDelegate makeInitialDefaults];

    NSError *error = nil;
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    BOOL usingDefaultStorageLocation = [[userDefaults valueForKey:kUserDefaultsUsingDefaultStorage] boolValue];
    NSData *bookmark = [userDefaults valueForKey:usingDefaultStorageLocation ? kUserDefaultsDefaultStoragePath : kUserDefaultsCustomStoragePath];
    NSAssert(nil != bookmark, @"User defaults are broken: no storage path");
    BOOL isStale = NO;
    NSURL *storageDirectory = [NSURL URLByResolvingBookmarkData:bookmark
                                                        options:NSURLBookmarkResolutionWithSecurityScope
                                                  relativeToURL:nil
                                            bookmarkDataIsStale:&isStale
                                                          error:&error];
    // TODO: ponder what to do if this fails
    NSAssert(nil == error, @"Error getting storage directory: %@", error.localizedDescription);
    NSAssert(nil != storageDirectory, @"Got no error but no storage directory");
    NSAssert(NO == isStale, @"Storage directory is stale");

    // TODO: icky self use
    NSPersistentStoreCoordinator *store = self.persistentContainer.persistentStoreCoordinator;
    self->_libraryController = [[LibraryWriteCoordinator alloc] initWithPersistentStore:store];
    self->_importCoordinator = [[ImportCoordinator alloc] initWithPersistentStore:store
                                                                 storageDirectory:storageDirectory];

    // We wait a minute, and then see if we need to do any house keeping, so as not to add load whilst the
    // user is in the "I launched this to do a specific thing" window
    @weakify(self);
    self.launchTaskTimer = [NSTimer scheduledTimerWithTimeInterval:60.0
                                                           repeats:NO
                                                             block:^(__unused NSTimer * _Nonnull timer) {
        @strongify(self);
        if (nil == self) {
            return;
        }

        [self.libraryController carryOutCleanUp];
    }];

    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *trashURL = [fm URLForDirectory:NSTrashDirectory
                                 inDomain:NSAllDomainsMask
                        appropriateForURL:nil
                                   create:NO
                                    error:&error];
    self.trashDisplayName = @"Trash";
    if (nil != error) {
        NSAssert(nil == trashURL, @"Got error and return value");
        // Renaming the menu item isn't essential, so just log the failure and move on
        NSLog(@"Failed to get trash URL: %@", error);
    } else {
        NSAssert(nil != trashURL, @"Got no error and no value");
        self.trashDisplayName = [fm displayNameAtPath:[trashURL path]];
        [self.emptyTrashMenuItem setTitle:[NSString stringWithFormat:@"Empty %@...", self.trashDisplayName]];
    }

    self.mainWindowController = [[RootWindowController alloc] initWithWindowNibName:@"RootWindowController"
                                                                        viewContext:self.persistentContainer.viewContext
                                                                   trashDisplayName:self.trashDisplayName];
    [self.mainWindowController showWindow:nil];
}


- (void)applicationWillTerminate:(NSNotification * _Nonnull)aNotification {
}


- (BOOL)applicationSupportsSecureRestorableState:(NSApplication * _Nonnull)app {
    return YES;
}


#pragma mark - Menu items

// It's a downside of using an NSWindowController with its own xib that you can't connect up the menu items more directly
- (IBAction)import:(id _Nullable)sender {
    [self.mainWindowController import:sender];
}


- (IBAction)settings:(id _Nullable)sender {
    if (nil == self.settingsWindowController) {
        self.settingsWindowController = [[SettingsWindowController alloc] initWithWindowNibName:@"SettingsWindowController"];
    }
    [self.settingsWindowController showWindow:nil];
}

- (IBAction)createGroup:(id _Nullable)sender {
    [self.mainWindowController showGroupCreatePanel:sender];
}

- (IBAction)emptyTrash:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    // TODO: Get an indication of how many items we'll remove
    alert.messageText = [NSString stringWithFormat:@"Emptying %@", self.trashDisplayName];
    alert.informativeText = NSLocalizedString(@"Permenently removing assets from $APP, this can not be undone.", nil);
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
    [alert addButtonWithTitle:NSLocalizedString(@"OK", nil)];
    [alert beginSheetModalForWindow:self.mainWindowController.window
                  completionHandler:^(NSModalResponse returnCode) {
        if (NSAlertFirstButtonReturn == returnCode) {
            return;
        }
        NSAssert(NSAlertSecondButtonReturn == returnCode, @"Expected button %ld, got %ld", NSAlertSecondButtonReturn, returnCode);
        [self.libraryController moveDeletedAssetsToTrash:^(BOOL success, NSError * _Nullable error) {
            if (nil != error) {
                NSAssert(NO == success, @"Got error but succcess");
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSAlert *alert = [NSAlert alertWithError:error];
                    [alert runModal];
                });
            }
            NSAssert(NO != success, @"Got no error but not success");
        }];
    }];
}

- (IBAction)debugRegenerateThumbnail:(id)sender {
    [self.mainWindowController debugRegenerateThumbnail:sender];
}

- (IBAction)debugRegenerateScannedText:(id)sender {
    [self.mainWindowController debugRegenerateScannedText:sender];
}


#pragma mark - Core Data stack

@synthesize persistentContainer = _persistentContainer;

- (NSPersistentContainer *)persistentContainer {
    // The persistent container for the application. This implementation creates and returns a container, having loaded the store for the application to it.
    @synchronized (self) {
        if (_persistentContainer == nil) {
            _persistentContainer = [[NSPersistentContainer alloc] initWithName:@"LibraryModel"];
            [_persistentContainer loadPersistentStoresWithCompletionHandler:^(__unused NSPersistentStoreDescription *storeDescription, NSError *error) {
                if (error != nil) {
                    // Replace this implementation with code to handle the error appropriately.
                    // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                    /*
                     Typical reasons for an error here include:
                     * The parent directory does not exist, cannot be created, or disallows writing.
                     * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                     * The device is out of space.
                     * The store could not be migrated to the current model version.
                     Check the error message to determine what the actual problem was.
                     */
                    NSLog(@"Unresolved error %@, %@", error, error.userInfo);
                    abort();
                }
            }];
        }
    }

    return _persistentContainer;
}

#pragma mark - Core Data Saving and Undo support

- (void)save {
    // Performs the save action for the application, which is to send the save: message to the application's managed object context. Any encountered errors are presented to the user.
    NSManagedObjectContext *context = self.persistentContainer.viewContext;

    if (![context commitEditing]) {
        NSLog(@"%@:%@ unable to commit editing before saving", [self class], NSStringFromSelector(_cmd));
    }

    NSError *error = nil;
    if (context.hasChanges && ![context save:&error]) {
        // Customize this code block to include application-specific recovery steps.
        [[NSApplication sharedApplication] presentError:error];
    }
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window {
    // Returns the NSUndoManager for the application. In this case, the manager returned is that of the managed object context for the application.
    return self.persistentContainer.viewContext.undoManager;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    // Save changes in the application's managed object context before the application terminates.
    NSManagedObjectContext *context = self.persistentContainer.viewContext;

    if (![context commitEditing]) {
        NSLog(@"%@:%@ unable to commit editing to terminate", [self class], NSStringFromSelector(_cmd));
        return NSTerminateCancel;
    }

    if (!context.hasChanges) {
        return NSTerminateNow;
    }

    NSError *error = nil;
    if (![context save:&error]) {

        // Customize this code block to include application-specific recovery steps.
        BOOL result = [sender presentError:error];
        if (result) {
            return NSTerminateCancel;
        }

        NSString *question = NSLocalizedString(@"Could not save changes while quitting. Quit anyway?", @"Quit without saves error question message");
        NSString *info = NSLocalizedString(@"Quitting now will lose any changes you have made since the last successful save", @"Quit without saves error question info");
        NSString *quitButton = NSLocalizedString(@"Quit anyway", @"Quit anyway button title");
        NSString *cancelButton = NSLocalizedString(@"Cancel", @"Cancel button title");
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:question];
        [alert setInformativeText:info];
        [alert addButtonWithTitle:quitButton];
        [alert addButtonWithTitle:cancelButton];

        NSInteger answer = [alert runModal];

        if (answer == NSAlertSecondButtonReturn) {
            return NSTerminateCancel;
        }
    }

    return NSTerminateNow;
}

@end
