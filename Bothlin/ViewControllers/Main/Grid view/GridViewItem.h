//
//  GridViewItem.h
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 11/10/2023.
//

#import <Cocoa/Cocoa.h>

#import "DragSourceView.h"

@class Item;

NS_ASSUME_NONNULL_BEGIN

@class GridViewItem;

@protocol GridViewItemDelegate <NSObject>

- (void)gridViewItemWasDoubleClicked:(GridViewItem *)gridViewItem;

@end

@interface GridViewItem : NSCollectionViewItem <DragSourceViewDelegate, NSFilePromiseProviderDelegate>

@property (nonatomic, weak, readwrite) IBOutlet DragSourceView *dragSourceView;

@property (nonatomic, weak, readwrite) id<GridViewItemDelegate> delegate;
@property (nonatomic, strong, readwrite) Item *item;

@end

NS_ASSUME_NONNULL_END
