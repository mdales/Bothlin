//
//  SettingsWindowController.m
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 08/10/2023.
//

#import "SettingsWindowController.h"
#import "AppDelegate.h"
#import "Helpers.h"

typedef NS_ENUM(NSInteger, StorageLocationValue) {
    StorageLocationValueDefault = 1,
    StorageLocationValueCustom = 2
};

@interface SettingsWindowController ()

@end

@implementation SettingsWindowController

- (void)windowDidLoad {
    [super windowDidLoad];
    [self syncUIWithDefaults];
}

- (void)syncUIWithDefaults {
    dispatch_assert_queue(dispatch_get_main_queue());

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL useDefaultStorage = [[defaults valueForKey:kUserDefaultsUsingDefaultStorage] boolValue];
    [self.defaultStorageLocationRadio setState: useDefaultStorage ? NSControlStateValueOn : NSControlStateValueOff];
    [self.customStorageLocationRadio setState: useDefaultStorage ? NSControlStateValueOff : NSControlStateValueOn];


    NSData *storagePathData = [defaults valueForKey: useDefaultStorage ? kUserDefaultsDefaultStoragePath : kUserDefaultsCustomStoragePath];
    if (nil != storagePathData) {
        NSError *error = nil;
        BOOL isStale = NO;
        NSURL *storageURL = [NSURL URLByResolvingBookmarkData:storagePathData
                                                      options:NSURLBookmarkResolutionWithSecurityScope
                                                relativeToURL:nil
                                          bookmarkDataIsStale:&isStale
                                                        error:&error];
        if (nil == error) {
            [self.customStorageLocationLabel setStringValue:storageURL.path];
        } else {
            NSLog(@"Failed to decode URL: %@", error);
        }
    }
}

- (IBAction)storageLocationChanged:(id)sender {
    /* TODO: This implementation is not very safe - there's lots that we should be doing about
     * migrating data etc. here, but for now we have a single user (me, the author), and I just want
     * to embed the idea that the image storage may be detached from the app's storage, so that later
     * on when I want to have multiple storage locations (i.e., some are on local disk, some are on
     * NAS, etc.) there's less in terms of built in assumptions that we have everything in the
     * app's container.
     */
    NSAssert([sender isKindOfClass:[NSButton class]], @"Incorrect outlet wired to storage change action");
    NSButton *radio = (NSButton *)sender;
    StorageLocationValue targetLocationValue = (StorageLocationValue)radio.tag;
    NSAssert((targetLocationValue == StorageLocationValueDefault) || (targetLocationValue == StorageLocationValueCustom), @"tag incorrectly set for storage type selection radio");

    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    BOOL usingDefaultStorage = [[userDefaults valueForKey:kUserDefaultsUsingDefaultStorage] boolValue];

    if (StorageLocationValueCustom == targetLocationValue) {
        // User opted for custom location
        if (NO == usingDefaultStorage) {
            return;
        }
        // If the user wants to select where they store things, make them pick
        NSOpenPanel* panel = [NSOpenPanel openPanel];
        panel.canChooseFiles = NO;
        panel.canChooseDirectories = YES;
        panel.canCreateDirectories = YES;

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
                NSAssert(1 == [urls count], @"Expected user to select single directory, got %lu", [urls count]);
                NSURL *targetDirectory = [urls firstObject];
                NSError *error = nil;
                NSData *bookmark = [targetDirectory bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope
                                             includingResourceValuesForKeys:nil
                                                              relativeToURL:nil
                                                                      error:&error];
                if (nil != error) {
                    NSAssert(nil == bookmark, @"Got error and bookmark");
                    // error so set things back
                    [self.defaultStorageLocationRadio setState: usingDefaultStorage ? NSControlStateValueOn : NSControlStateValueOff];
                    [self.customStorageLocationRadio setState: usingDefaultStorage ? NSControlStateValueOff : NSControlStateValueOn];
                    
                    NSAlert *alert = [NSAlert alertWithError:error];
                    [alert runModal];
                    return;
                }
                NSAssert(nil != bookmark, @"Got no error and no bookmark");

                [userDefaults setValue:bookmark
                                forKey:kUserDefaultsCustomStoragePath];
                [userDefaults setValue:@(NO)
                                forKey:kUserDefaultsUsingDefaultStorage];

                [self.customStorageLocationLabel setStringValue:[targetDirectory path]];
            } else {
                // User cancelled, so go back to previous state
                [self.defaultStorageLocationRadio setState: usingDefaultStorage ? NSControlStateValueOn : NSControlStateValueOff];
                [self.customStorageLocationRadio setState: usingDefaultStorage ? NSControlStateValueOff : NSControlStateValueOn];
            }
        }];
    } else {
        // User opted for default location
        if (NO != usingDefaultStorage) {
            return;
        }
        [userDefaults setValue:@(YES)
                        forKey:kUserDefaultsUsingDefaultStorage];
        [self syncUIWithDefaults];
    }

}


@end
