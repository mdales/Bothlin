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

@property (nonatomic, strong, readwrite) Asset *asset;

@end

@implementation SingleViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    NSAssert(nil == self.previewView, @"Expected no preview view yet");
    self.previewView = [[QLPreviewView alloc] initWithFrame:self.view.frame
                                                      style:QLPreviewViewStyleNormal];
    [self.previewView setAutoresizingMask:NSViewHeightSizable | NSViewWidthSizable];
    [self.previewView setAutoresizesSubviews:YES];
    [self.previewView setShouldCloseWithWindow:NO];
    [self.view addSubview:self.previewView];

    NSClickGestureRecognizer *doubleClickGesture =
    [[NSClickGestureRecognizer alloc] initWithTarget:self
                                              action:@selector(onDoubleClick:)];
    [doubleClickGesture setNumberOfClicksRequired:2];
    [doubleClickGesture setDelaysPrimaryMouseButtonEvents:NO];
    [self.view addGestureRecognizer:doubleClickGesture];
}

- (void)viewWillAppear {
    [super viewWillAppear];
    if (nil == self.previewView.previewItem) {
        [self loadAsset];
    }
}

#pragma mark - IKImageView delegates



#pragma mark - gestures

- (void)onDoubleClick:(NSGestureRecognizer *)sender {
    dispatch_assert_queue(dispatch_get_main_queue());
    [self.delegate singleViewItemWasDoubleClicked:self];
}

#pragma mark - data

- (void)setAssetForDisplay:(Asset *)asset {
    if (asset.objectID == self.asset.objectID) {
        return;
    }

    self.asset = asset;
    self.previewView.previewItem = nil;

    if (nil != self.view.superview) {
        [self loadAsset];
    }
}

- (void)loadAsset {
    dispatch_assert_queue(dispatch_get_main_queue());
    if (nil == self.asset) {
        return;
    }

    __block NSError *error = nil;
    NSURL *secureURL = [self.asset decodeSecureURL:&error];
    if (nil != error) {
        // TODO: Alert user
        NSLog(@"Failed to get secure URL for %@: %@", self.asset, error);
        return;
    }

    [secureURL secureAccessWithBlock:^(NSURL * _Nonnull url, BOOL canAccess) {
        if (NO == canAccess) {
            error = [NSError errorWithDomain:SingleViewControllerErrorDomain
                                        code:SingleViewControllerErrorImageNoAccess
                                    userInfo:@{@"URL": url}];
            return;
        }

        [self.previewView setPreviewItem:url];
    }];
    if (nil != error) {
        // TODO: Alert user
        NSLog(@"Failed to load %@: %@", self.asset.name, error);
        return;
    }
}

@end
