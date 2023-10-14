//
//  SidebarController.h
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 28/09/2023.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class SidebarController;

@protocol SidebarControllerDelegate <NSObject>

- (void)addGroupViaSidebarController:(SidebarController *)sidebarController;

@end

@interface SidebarController : NSViewController <NSOutlineViewDataSource, NSOutlineViewDelegate>

@property (nonatomic, weak, readwrite) IBOutlet NSOutlineView *outlineView;
@property (nonatomic, weak, readwrite) id<SidebarControllerDelegate> delegate;

- (IBAction)addItemFromOutlineView:(id)sender;

// Only safe on mainQ
- (void)reloadData;

@end

NS_ASSUME_NONNULL_END
