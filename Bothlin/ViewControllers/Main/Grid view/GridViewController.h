//
//  GridViewController.h
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 28/09/2023.
//

#import <Cocoa/Cocoa.h>

#import "GridViewItem.h"
#import "DragTargetView.h"

@class Asset;

NS_ASSUME_NONNULL_BEGIN

@class GridViewController;

@protocol GridViewControllerDelegate <NSObject>

- (void)gridViewController:(GridViewController *)gridViewController
        selectionDidChange:(NSIndexPath *)selectedIndexPath;

- (void)gridViewController:(GridViewController *)gridViewController
         doubleClickedItem:(Asset *)item;

- (void)gridViewController:(GridViewController *)gridViewController
     didReceiveDroppedURLs:(NSSet<NSURL *> *)URLs;

// TODO: Better naming needed, but I hope to remove this endless delegate chain
// at some point, as it's somewhat tedious.
- (BOOL)gridViewController:(GridViewController *)gridViewController
                      item:(Asset *)item
   wasDraggedOnSidebarItem:(SidebarItem *)sidebarItem;

@end

@interface GridViewController : NSViewController <NSCollectionViewDelegate, NSCollectionViewDataSource, GridViewItemDelegate, DragTargetViewDelegate>

// Only access on mainQ
@property (nonatomic, weak, readwrite) IBOutlet NSCollectionView *collectionView;
@property (nonatomic, weak, readwrite) IBOutlet DragTargetView *dragTargetView;
@property (nonatomic, weak, readwrite) id<GridViewControllerDelegate> delegate;

- (void)setAssets:(NSArray<Asset *> *)assets
     withSelected:(NSIndexPath *)selected;

@end

NS_ASSUME_NONNULL_END
