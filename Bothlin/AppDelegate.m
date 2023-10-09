//
//  AppDelegate.m
//  Bothlin
//
//  Created by Michael Dales on 16/09/2023.
//

#import "AppDelegate.h"
#import "LibraryController.h"
#import "RootWindowController.h"
#import "SettingsWindowController.h"

NSString * __nonnull const kUserDefaultsUsingDefaultStorage = @"kUserDefaultsUsingDefaultStorage";
NSString * __nonnull const kUserDefaultsDefaultStoragePath = @"kUserDefaultsDefaultStoragePath";
NSString * __nonnull const kUserDefaultsCustomStoragePath = @"kUserDefaultsCustomStoragePath";

@interface AppDelegate ()

@property (nonatomic, strong, readwrite) RootWindowController *mainWindowController;
@property (nonatomic, strong, readwrite) SettingsWindowController *settingsWindowController;

@end

@implementation AppDelegate

+ (void)makeInitialDefaults {
    NSFileManager *fm = [NSFileManager defaultManager];

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSAssert(0 < [paths count], @"Expected at least one documents folder, got none");
    NSString *documntsDirectory = paths.firstObject;
    NSString *defaultStorageFolderPath = [documntsDirectory stringByAppendingPathComponent:@"Screenshots"];
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
    };

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults registerDefaults:initialDefaultValues];
}


- (void)applicationDidFinishLaunching:(NSNotification * _Nonnull)aNotification {
    [AppDelegate makeInitialDefaults];

    // TODO: icky self use
    NSPersistentStoreCoordinator *store = self.persistentContainer.persistentStoreCoordinator;
    self->_libraryController = [[LibraryController alloc] initWithPersistentStore:store];

    self.mainWindowController = [[RootWindowController alloc] initWithWindowNibName:@"RootWindowController"];
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
