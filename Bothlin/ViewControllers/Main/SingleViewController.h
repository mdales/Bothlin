//
//  SingleViewController.h
//  Bothlin
//
//  Created by Michael Dales on 28/09/2023.
//

#import <Cocoa/Cocoa.h>

@class Item;
@class SingleViewController;

NS_ASSUME_NONNULL_BEGIN

@protocol SingleViewControllerDelegate <NSObject>

- (void)singleViewItemWasDoubleClicked:(SingleViewController *)singleViewItem;

@end

@interface SingleViewController : NSViewController

@property (nonatomic, weak, readwrite) id<SingleViewControllerDelegate> delegate;
@property (nonatomic, weak, readwrite) IBOutlet NSImageView *imageView;

- (void)setItemForDisplay:(Item *)item;

@end

NS_ASSUME_NONNULL_END
