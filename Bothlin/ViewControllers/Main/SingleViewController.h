//
//  SingleViewController.h
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 28/09/2023.
//

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>


@class Asset;
@class SingleViewController;

NS_ASSUME_NONNULL_BEGIN

@protocol SingleViewControllerDelegate <NSObject>

- (void)singleViewItemWasDoubleClicked:(SingleViewController *)singleViewItem;

@end

@interface SingleViewController : NSViewController

@property (nonatomic, weak, readwrite) id<SingleViewControllerDelegate> delegate;
//@property (nonatomic, weak, readwrite) IBOutlet IKImageView *imageView;
@property (nonatomic, strong, readwrite) IBOutlet QLPreviewView *previewView;

- (void)setAssetForDisplay:(Asset * _Nullable)item;

@end

NS_ASSUME_NONNULL_END
