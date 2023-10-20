//
//  ItemsDisplayController.h
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
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

- (void)itemsDisplayController:(ItemsDisplayController *)itemsDisplayController
         didReceiveDroppedURLs:(NSSet<NSURL *> *)URLs;

// TODO: Better naming needed, but I hope to remove this endless delegate chain
// at some point, as it's somewhat tedious.
- (BOOL)itemsDisplayController:(ItemsDisplayController *)itemsDisplayController
                          item:(Item *)item
       wasDraggedOnSidebarItem:(SidebarItem *)sidebarItem;

@end

@interface ItemsDisplayController : NSViewController <GridViewControllerDelegate, SingleViewControllerDelegate>

// Only safe on mainQ
@property (nonatomic, weak, readwrite) id<ItemsDisplayControllerDelegate> delegate;
@property (nonatomic, readwrite) ItemsDisplayStyle displayStyle;

- (void)setItems:(NSArray<Item *> *)items
    withSelected:(Item * _Nullable)selected;

@end

NS_ASSUME_NONNULL_END
