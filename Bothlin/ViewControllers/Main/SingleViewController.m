//
//  SingleViewController.m
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 28/09/2023.
//

#import "SingleViewController.h"
#import "NSURL+SecureAccess.h"
#import "AssetExtension.h"

NSErrorDomain __nonnull const SingleViewControllerErrorDomain = @"com.digitalflapjack.SingleViewController";
typedef NS_ERROR_ENUM(SingleViewControllerErrorDomain, SingleViewControllerErrorCode) {
    SingleViewControllerErrorUnknown,
    SingleViewControllerErrorImageOpenFailed,
    SingleViewControllerErrorImageNoAccess,
    SingleViewControllerErrorImageCreateFailed,
};


@interface SingleViewController ()

@property (nonatomic, strong, readwrite) Asset *item;

@end

@implementation SingleViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self.imageView setDoubleClickOpensImageEditPanel:NO];
    [self.imageView setCurrentToolMode:IKToolModeMove];
    [self.imageView setDelegate:self];

    NSClickGestureRecognizer *doubleClickGesture =
    [[NSClickGestureRecognizer alloc] initWithTarget:self
                                              action:@selector(onDoubleClick:)];
    [doubleClickGesture setNumberOfClicksRequired:2];
    [doubleClickGesture setDelaysPrimaryMouseButtonEvents:NO];
    [self.view addGestureRecognizer:doubleClickGesture];
}

- (void)viewWillAppear {
    [super viewWillAppear];
    if (nil == self.imageView.image) {
        [self loadImage];
    }
}

#pragma mark - IKImageView delegates



#pragma mark - gestures

- (void)onDoubleClick:(NSGestureRecognizer *)sender {
    dispatch_assert_queue(dispatch_get_main_queue());
    [self.delegate singleViewItemWasDoubleClicked:self];
}

#pragma mark - data

- (void)setItemForDisplay:(Asset *)item {
    if (item == self.item) {
        return;
    }

    self.item = item;
    [self.imageView setImageWithURL:nil]; // TODO: Trying to clear image

    if (nil != self.view.superview) {
        [self loadImage];
    }
}

- (void)loadImage {
    dispatch_assert_queue(dispatch_get_main_queue());
    if (nil == self.item) {
        return;
    }

    __block NSError *error = nil;
    NSURL *secureURL = [self.item decodeSecureURL:&error];
    if (nil != error) {
        // TODO: Alert user
        NSLog(@"Failed to get secure URL for %@: %@", self.item, error);
        return;
    }

    [secureURL secureAccessWithBlock:^(NSURL * _Nonnull url, BOOL canAccess) {
        // TODO: shift all this to background queue once working
        if (NO == canAccess) {
            error = [NSError errorWithDomain:SingleViewControllerErrorDomain
                                        code:SingleViewControllerErrorImageNoAccess
                                    userInfo:@{@"URL": url}];
            return;
        }

        CGImageSourceRef imageSource = CGImageSourceCreateWithURL((CFURLRef)url, NULL);
        if (NULL == imageSource) {
            error = [NSError errorWithDomain:SingleViewControllerErrorDomain
                                        code:SingleViewControllerErrorImageOpenFailed
                                    userInfo:@{@"URL": url}];
            return;
        }

        CGImageRef image = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
        if (NULL == image) {
            error = [NSError errorWithDomain:SingleViewControllerErrorDomain
                                        code:SingleViewControllerErrorImageCreateFailed
                                    userInfo:@{@"URL": url}];
            CFRelease(imageSource);
            return;
        }

        NSDictionary *imageProperties = (NSDictionary*)CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(imageSource, 0, NULL));
        [self.imageView setImage:image
                 imageProperties:imageProperties];

        // TODO: I'm not sure what the ownership is here, but if I release the image and source here the image won't load
        // Do I need to release them when I unset the image in the image view, or does IKImageView do that?
        // CGImageRelease(image);
        // CFRelease(imageSource);
    }];
    if (nil != error) {
        // TODO: Alert user
        NSLog(@"Failed to load %@: %@", self.item.name, error);
        return;
    }
    [self.imageView zoomImageToFit:self];
}

@end
