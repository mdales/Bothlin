//
//  GridViewItemRootView.h
//  Bothlin
//
//  Created by Michael Dales on 31/10/2023.
//

#import <Cocoa/Cocoa.h>

@class GridViewItemRootView;

NS_ASSUME_NONNULL_BEGIN

@protocol GridViewItemRootViewDelegate <NSObject>

- (void)gridViewRootViewWasDoubleClicked:(GridViewItemRootView *)gridViewItemRootView;

@end

@interface GridViewItemRootView : NSView

@property (nonatomic, weak, readwrite) id<GridViewItemRootViewDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
