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

- (void)singleViewItemWasDimissed:(SingleViewController *)singleViewItem;

- (void)singleViewController:(SingleViewController *)singleViewController
           failedToLoadAsset:(Asset *)asset
                       error:(NSError *)error;

- (BOOL)singleViewController:(SingleViewController *)singleViewController
            moveSelectionBy:(NSInteger)distance;

@end

@interface SingleViewController : NSViewController

@property (nonatomic, weak, readwrite) id<SingleViewControllerDelegate> delegate;
@property (nonatomic, strong, readwrite) IBOutlet QLPreviewView *previewView;

- (void)setAssetForDisplay:(Asset * _Nullable)item;

@end

NS_ASSUME_NONNULL_END
