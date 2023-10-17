//
//  SidebarController.h
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 28/09/2023.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class Group;
@class SidebarController;

@protocol SidebarControllerDelegate <NSObject>

- (void)addGroupViaSidebarController:(SidebarController *)sidebarController;
- (void)sidebarController:(SidebarController *)sidebarController
  didChangeSelectedOption:(NSFetchRequest *)fetchRequest;

@end

@interface SidebarController : NSViewController <NSOutlineViewDataSource, NSOutlineViewDelegate>

@property (nonatomic, weak, readwrite) IBOutlet NSOutlineView *outlineView;
@property (nonatomic, weak, readwrite) id<SidebarControllerDelegate> delegate;

- (IBAction)addItemFromOutlineView:(id)sender;

// Only safe on mainQ
- (void)setGroups:(NSArray<Group *> *)groups;
- (void)showGroups;
- (NSFetchRequest *)selectedOption;

@end

NS_ASSUME_NONNULL_END
