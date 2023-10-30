//
//  GridViewItem.h
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 11/10/2023.
//

#import <Cocoa/Cocoa.h>

@class Asset;
@class SidebarItem;

NS_ASSUME_NONNULL_BEGIN

@class GridViewItem;

@protocol GridViewItemDelegate <NSObject>

- (void)gridViewItemWasDoubleClicked:(GridViewItem *)gridViewItem;
- (BOOL)gridViewItem:(GridViewItem *)gridViewItem
wasDraggedOnSidebarItem:(SidebarItem *)sidebarItem;

@end

@interface GridViewItem : NSCollectionViewItem <NSFilePromiseProviderDelegate>

@property (nonatomic, weak, readwrite) IBOutlet NSView *dragSourceView;
@property (nonatomic, weak, readwrite) IBOutlet NSImageView *favouriteIndicator;

@property (nonatomic, weak, readwrite) id<GridViewItemDelegate> delegate;
@property (nonatomic, strong, readwrite) Asset *asset;

@end

NS_ASSUME_NONNULL_END
