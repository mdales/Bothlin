//
//  AppDelegate.h
//  Bothlin
//
//  Created by Michael Dales on 16/09/2023.
//

#import <Cocoa/Cocoa.h>

@class LibraryController;

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (readonly, nonatomic, strong) NSPersistentContainer *persistentContainer;
@property (readonly, nonatomic, strong) LibraryController *libraryController;

- (IBAction)import:(id)sender;

@end

