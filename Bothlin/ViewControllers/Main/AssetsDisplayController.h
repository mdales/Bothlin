//
//  ItemsDisplayController.h
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 28/09/2023.
//

#import <Cocoa/Cocoa.h>

#import "GridViewController.h"
#import "SingleViewController.h"

@class Asset;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, ItemsDisplayStyle) {
    ItemsDisplayStyleGrid,
    ItemsDisplayStyleSingle
};

@class AssetsDisplayController;

@protocol ItemsDisplayControllerDelegate <NSObject>

- (void)assetsDisplayController:(AssetsDisplayController *)assetsDisplayController
             selectionDidChange:(NSIndexPath *)selectedIndexPath;

- (void)assetsDisplayController:(AssetsDisplayController *)assetsDisplayController
             viewStyleDidChange:(ItemsDisplayStyle)displayStyle;

- (void)assetsDisplayController:(AssetsDisplayController *)assetsDisplayController
          didReceiveDroppedURLs:(NSSet<NSURL *> *)URLs;

// TODO: Better naming needed, but I hope to remove this endless delegate chain
// at some point, as it's somewhat tedious.
- (BOOL)assetsDisplayController:(AssetsDisplayController *)assetsDisplayController
                          item:(Asset *)item
       wasDraggedOnSidebarItem:(SidebarItem *)sidebarItem;

@end

@interface AssetsDisplayController : NSViewController <GridViewControllerDelegate, SingleViewControllerDelegate>

// Only safe on mainQ
@property (nonatomic, weak, readwrite) id<ItemsDisplayControllerDelegate> delegate;
@property (nonatomic, readwrite) ItemsDisplayStyle displayStyle;

- (void)setAssets:(NSArray<Asset *> *)assets
     withSelected:(NSIndexPath *)selected;

@end

NS_ASSUME_NONNULL_END
