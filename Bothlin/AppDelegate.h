//
//  AppDelegate.h
//  Bothlin
//
//  Created by Michael Dales on 16/09/2023.
//

#import <Cocoa/Cocoa.h>

@class LibraryController;

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (readonly, strong) NSPersistentContainer *persistentContainer;
@property (readonly, strong) LibraryController *libraryController;

@end

