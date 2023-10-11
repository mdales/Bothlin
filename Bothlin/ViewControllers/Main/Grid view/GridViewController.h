//
//  GridViewController.h
//  Bothlin
//
//  Created by Michael Dales on 28/09/2023.
//

#import <Cocoa/Cocoa.h>

#import "GridViewItem.h"
#import "DragTargetView.h"

@class Item;

NS_ASSUME_NONNULL_BEGIN

@class GridViewController;

@protocol GridViewControllerDelegate <NSObject>

- (void)gridViewController:(GridViewController *)gridViewController
        selectionDidChange:(Item *)selectedItem;

- (void)gridViewController:(GridViewController *)gridViewController
         doubleClickedItem:(Item *)item;

- (void)gridViewController:(GridViewController *)gridViewController
     didReceiveDroppedURLs:(NSSet<NSURL *> *)URLs;

@end

@interface GridViewController : NSViewController <NSCollectionViewDelegate, NSCollectionViewDataSource, GridViewItemDelegate, DragTargetViewDelegate>

// Only access on mainQ
@property (nonatomic, weak, readwrite) IBOutlet NSCollectionView *collectionView;
@property (nonatomic, weak, readwrite) IBOutlet DragTargetView *dragTargetView;
@property (nonatomic, weak, readwrite) id<GridViewControllerDelegate> delegate;
@property (nonatomic, strong, readwrite) Item *selectedItem;

- (BOOL)reloadData:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
