//
//  GridViewController.h
//  Bothlin
//
//  Created by Michael Dales on 28/09/2023.
//

#import <Cocoa/Cocoa.h>

@class Item;

NS_ASSUME_NONNULL_BEGIN

@protocol GridViewControllerDelegate <NSObject>

- (void)gridViewControllerSelectionDidChange: (Item *)selectedItem;

@end

@interface GridViewController : NSViewController <NSCollectionViewDelegate, NSCollectionViewDataSource>

// Only access on mainQ
@property (nonatomic, weak, readwrite) IBOutlet NSCollectionView *collectionView;
@property (nonatomic, weak, readwrite) id<GridViewControllerDelegate> delegate;
@property (nonatomic, strong, readwrite) Item *selectedItem;

- (BOOL)reloadData: (NSError **)error;

@end

NS_ASSUME_NONNULL_END
