//
//  ItemsDisplayController.h
//  Bothlin
//
//  Created by Michael Dales on 28/09/2023.
//

#import <Cocoa/Cocoa.h>

#import "GridViewController.h"

@class Item;

NS_ASSUME_NONNULL_BEGIN

@class ItemsDisplayController;

@protocol ItemsDisplayControllerDelegate <NSObject>

- (void)itemsDisplayController:(ItemsDisplayController *)itemsDisplayController
            selectionDidChange:(Item *)selectedItem;

@end

@interface ItemsDisplayController : NSViewController <GridViewControllerDelegate>

@property (nonatomic, weak, readwrite) id<ItemsDisplayControllerDelegate> delegate;

- (void)reloadData;
- (void)toggleView;

@end

NS_ASSUME_NONNULL_END
