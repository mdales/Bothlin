//
//  AppDelegate.h
//  Bothlin
//
//  Created by Michael Dales on 16/09/2023.
//

#import <Cocoa/Cocoa.h>

@class LibraryController;

extern NSString * __nonnull const kUserDefaultsUsingDefaultStorage;
extern NSString * __nonnull const kUserDefaultsDefaultStoragePath;
extern NSString * __nonnull const kUserDefaultsCustomStoragePath;

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (readonly, nonatomic, strong) NSPersistentContainer * _Nonnull persistentContainer;
@property (readonly, nonatomic, strong) LibraryController * _Nonnull libraryController;

- (IBAction)import:(id _Nullable)sender;
- (IBAction)settings:(id _Nullable)sender;

@end

