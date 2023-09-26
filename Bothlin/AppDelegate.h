//
//  AppDelegate.h
//  OldSkool
//
//  Created by Michael Dales on 16/09/2023.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, NSSplitViewDelegate>

@property (readonly, strong) NSPersistentContainer *persistentContainer;

@property (weak, nonatomic) IBOutlet NSSplitView *toolbarSplitView;

@end

