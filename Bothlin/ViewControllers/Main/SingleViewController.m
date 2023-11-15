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


#pragma mark - gestures

- (void)onDoubleClick:(NSGestureRecognizer *)sender {
    dispatch_assert_queue(dispatch_get_main_queue());
    [self.delegate singleViewItemWasDimissed:self];
}

- (void)keyDown:(NSEvent *)event { 
    id<SingleViewControllerDelegate> delegate = self.delegate;
    if (nil == delegate) {
        [super keyDown:event];
        return;
    }

    if (NSKeyDown == event.type) {
        switch (event.keyCode) {
            case 49: // space
                [delegate singleViewItemWasDimissed:self];
                return;
            case 123: { // left arrow
                    BOOL success = [delegate singleViewController:self
                                                  moveSelectionBy:-1];
                    if (NO != success) {
                        return;
                    }
                }
                break;
            case 124: { // right arrow
                    BOOL success = [delegate singleViewController:self
                                                  moveSelectionBy:1];
                    if (NO != success) {
                        return;
                    }
                }
                break;
            default:
                NSLog(@"event: %@", event);
                break;
        }
    }
    [super keyDown:event];
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
    id<SingleViewControllerDelegate> delegate = self.delegate;

    __block NSError *error = nil;
    NSURL *secureURL = [self.asset decodeSecureURL:&error];
    if (nil != error) {
        [delegate singleViewController:self
                     failedToLoadAsset:self.asset
                                 error:error];
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
        [delegate singleViewController:self
                     failedToLoadAsset:self.asset
                                 error:error];
        return;
    }
}

@end
