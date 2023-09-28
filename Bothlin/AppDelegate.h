//
//  AppDelegate.h
//  OldSkool
//
//  Created by Michael Dales on 16/09/2023.
//

#import <Cocoa/Cocoa.h>

@class OSLibraryController;

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (readonly, strong) NSPersistentContainer *persistentContainer;
@property (readonly, strong) OSLibraryController *libraryController;

@end

