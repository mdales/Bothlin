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
@class SidebarItem;

@protocol SidebarControllerDelegate <NSObject>

- (void)addGroupViaSidebarController:(SidebarController *)sidebarController;
- (void)sidebarController:(SidebarController *)sidebarController
  didChangeSelectedOption:(SidebarItem *)selectedSidebarItem;

@end

@interface SidebarController : NSViewController <NSOutlineViewDataSource, NSOutlineViewDelegate>

@property (nonatomic, weak, readwrite) IBOutlet NSOutlineView *outlineView;
@property (nonatomic, weak, readwrite) id<SidebarControllerDelegate> delegate;

// Safe on mainQ only
@property (nonatomic, strong, readwrite) SidebarItem *sidebarTree;


- (IBAction)addItemFromOutlineView:(id)sender;

- (void)expandGroupsBranch;
- (NSFetchRequest *)selectedOption;

@end

NS_ASSUME_NONNULL_END
