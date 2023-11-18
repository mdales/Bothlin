//
//  AppDelegate.h
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 16/09/2023.
//

#import <Cocoa/Cocoa.h>

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

@property (readonly, nonatomic, strong) NSPersistentContainer * _Nonnull persistentContainer;
@property (readonly, nonatomic, strong) LibraryWriteCoordinator * _Nonnull libraryController;

- (IBAction)import:(id _Nullable)sender;
- (IBAction)settings:(id _Nullable)sender;
- (IBAction)createGroup:(id _Nullable)sender;
- (IBAction)emptyTrash:(id _Nullable)sender;
- (IBAction)debugRegenerateThumbnail:(id _Nullable)sender;
- (IBAction)debugRegenerateScannedText:(id _Nullable)sender;

@end

