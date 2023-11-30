//
//  AppDelegate.h
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 16/09/2023.
//

#import <Cocoa/Cocoa.h>

@class ImportCoordinator;
@class LibraryWriteCoordinator;

extern NSString * __nonnull const kUserDefaultsUsingDefaultStorage;
extern NSString * __nonnull const kUserDefaultsDefaultStoragePath;
extern NSString * __nonnull const kUserDefaultsCustomStoragePath;
extern NSString * __nonnull const kUserDefaultsExpandedSidebarItems;

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (nonatomic, weak, readwrite) IBOutlet NSMenuItem * _Nullable deleteAssetMenuItem;
@property (nonatomic, weak, readwrite) IBOutlet NSMenuItem * _Nullable emptyTrashMenuItem;
@property (nonatomic, weak, readwrite) IBOutlet NSMenuItem * _Nullable debugRegenerateThumbnailMenuItem;
@property (nonatomic, weak, readwrite) IBOutlet NSMenuItem * _Nullable debugRegenerateScannedTextMenuItem;

@property (nonatomic, strong, readonly) NSPersistentContainer * _Nonnull persistentContainer;
@property (nonatomic, strong, readonly) LibraryWriteCoordinator * _Nonnull libraryController;
@property (nonatomic, strong, readonly) ImportCoordinator * _Nonnull importCoordinator;

- (IBAction)import:(id _Nullable)sender;
- (IBAction)settings:(id _Nullable)sender;
- (IBAction)createGroup:(id _Nullable)sender;
- (IBAction)emptyTrash:(id _Nullable)sender;
- (IBAction)debugRegenerateThumbnail:(id _Nullable)sender;
- (IBAction)debugRegenerateScannedText:(id _Nullable)sender;

@end

