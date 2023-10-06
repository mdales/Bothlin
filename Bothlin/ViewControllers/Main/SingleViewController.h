//
//  SingleViewController.h
//  Bothlin
//
//  Created by Michael Dales on 28/09/2023.
//

#import <Cocoa/Cocoa.h>

@class Item;

NS_ASSUME_NONNULL_BEGIN

@interface SingleViewController : NSViewController

@property (nonatomic, weak, readwrite) IBOutlet NSImageView *imageView;

- (void)setItemForDisplay:(Item *)item;

@end

NS_ASSUME_NONNULL_END
