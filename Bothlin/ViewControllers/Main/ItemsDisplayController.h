//
//  ItemsDisplayController.h
//  Bothlin
//
//  Created by Michael Dales on 28/09/2023.
//

#import <Cocoa/Cocoa.h>

#import "GridViewController.h"
#import "SingleViewController.h"

@class Item;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, ItemsDisplayStyle) {
    ItemsDisplayStyleGrid,
    ItemsDisplayStyleSingle
};

@class ItemsDisplayController;

@protocol ItemsDisplayControllerDelegate <NSObject>

- (void)itemsDisplayController:(ItemsDisplayController *)itemsDisplayController
            selectionDidChange:(Item *)selectedItem;

- (void)itemsDisplayController:(ItemsDisplayController *)itemsDisplayController
            viewStyleDidChange:(ItemsDisplayStyle)displayStyle;

@end

@interface ItemsDisplayController : NSViewController <GridViewControllerDelegate, SingleViewControllerDelegate>

// Only safe on mainQ
@property (nonatomic, weak, readwrite) id<ItemsDisplayControllerDelegate> delegate;
@property (nonatomic, readwrite) ItemsDisplayStyle displayStyle;

- (void)reloadData;

@end

NS_ASSUME_NONNULL_END
