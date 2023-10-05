//
//  ItemsDisplayController.h
//  Bothlin
//
//  Created by Michael Dales on 28/09/2023.
//

#import <Cocoa/Cocoa.h>

@class GridViewController;

NS_ASSUME_NONNULL_BEGIN

@interface ItemsDisplayController : NSViewController

@property (nonatomic, strong, readonly) GridViewController *gridViewController;

- (void)reloadData;
- (void)toggleView;

@end

NS_ASSUME_NONNULL_END
