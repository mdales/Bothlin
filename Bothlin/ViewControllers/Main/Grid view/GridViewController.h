//
//  GridViewController.h
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 28/09/2023.
//

#import <Cocoa/Cocoa.h>

#import "GridViewItem.h"
#import "DragTargetView.h"
#import "KeyCollectionView.h"

@class Asset;

NS_ASSUME_NONNULL_BEGIN

@class GridViewController;

@protocol GridViewControllerDelegate <NSObject>

- (void)gridViewController:(GridViewController *)gridViewController
        selectionDidChange:(NSSet<NSIndexPath *> *)selectedIndexPaths;

- (void)gridViewController:(GridViewController *)gridViewController
         doubleClickedItem:(Asset *)item;

- (BOOL)gridViewController:(GridViewController *)gridViewController
     didReceiveDroppedURLs:(NSSet<NSURL *> *)URLs;

// TODO: Better naming needed, but I hope to remove this endless delegate chain
// at some point, as it's somewhat tedious.
- (BOOL)gridViewController:(GridViewController *)gridViewController
                    assets:(NSSet<Asset *> *)assets
   wasDraggedOnSidebarItem:(SidebarItem *)sidebarItem;

@end

@interface GridViewController : NSViewController <NSCollectionViewDelegate, GridViewItemDelegate, DragTargetViewDelegate, KeyCollectionViewDelegate>

// Only access on mainQ
@property (nonatomic, weak, readwrite) IBOutlet KeyCollectionView *collectionView;
@property (nonatomic, weak, readwrite) IBOutlet DragTargetView *dragTargetView;
@property (nonatomic, weak, readwrite) id<GridViewControllerDelegate> delegate;

- (void)setAssets:(NSArray<Asset *> *)assets
     withSelected:(NSSet<NSIndexPath *> *)selected;

- (NSUInteger)count;
- (NSSet<NSIndexPath *> *)currentSelection;
- (BOOL)currentSelectedItemFrame:(NSRect *)frame;

@end

NS_ASSUME_NONNULL_END
