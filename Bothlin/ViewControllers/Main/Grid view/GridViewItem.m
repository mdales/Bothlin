//
//  GridViewItem.m
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 11/10/2023.
//

#import "GridViewItem.h"
#import "AssetExtension.h"
#import "NSURL+SecureAccess.h"
#import "AssetPromiseProvider.h"

@interface GridViewItem ()

@property (nonatomic, strong, readonly) NSOperationQueue *workQueue;

@end

@implementation GridViewItem

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (nil != self) {
        self->_workQueue = [[NSOperationQueue alloc] init];
        [self->_workQueue setQualityOfService:NSQualityOfServiceUserInitiated];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    GridViewItemRootView *rootView = (GridViewItemRootView *)self.view;
    rootView.delegate = self;
}

- (void)viewDidAppear {
    [super viewDidAppear];

    // setSelected doesn't seem to take if it's called before the view appears
    NSColor *bgColor = [self isSelected] ? [NSColor selectedControlColor] : [NSColor clearColor];
    self.view.layer.backgroundColor = bgColor.CGColor;
}

- (void)setSelected:(BOOL)value {
    [super setSelected:value];
    NSColor *bgColor = value ? [NSColor selectedControlColor] : [NSColor clearColor];
    self.view.layer.backgroundColor = bgColor.CGColor;
}


#pragma mark - GridViewItemRootViewDelegate

- (void)gridViewRootViewWasDoubleClicked:(__unused GridViewItemRootView *)gridViewItemRootView {
    [self.delegate gridViewItemWasDoubleClicked:self];
}

#pragma mark - NSFilePromiseProviderDelegate

// TODO: move this code to GridViewController which now creates the promise

- (NSString*)filePromiseProvider:(NSFilePromiseProvider *)filePromiseProvider
                 fileNameForType:(NSString *)fileType {
    return self.asset.name;
}

- (NSOperationQueue*)operationQueueForFilePromiseProvider:(NSFilePromiseProvider *)filePromiseProvider {
    return self.workQueue;
}

- (void)filePromiseProvider:(NSFilePromiseProvider *)filePromiseProvider 
          writePromiseToURL:(NSURL *)destinationURL
          completionHandler:(void (^)(NSError * _Nullable))completionHandler {
    if (nil == filePromiseProvider.userInfo) {
        return;
    }

    __block NSError *error = nil;
    NSURL *sourceURL = [self.asset decodeSecureURL:&error];
    if (nil != error) {
        NSAssert(nil == sourceURL, @"both both error and url");
        completionHandler(error);
        return;
    }
    NSAssert(nil != sourceURL, @"got neither error nor url");

    __block BOOL success = NO;
    [sourceURL secureAccessWithBlock:^(NSURL * _Nonnull secureURL, __unused BOOL canAccess) {
        NSFileManager *fm = [NSFileManager defaultManager];
        success = [fm copyItemAtURL:secureURL
                              toURL:destinationURL
                              error:&error];
    }];
    if (nil != error) {
        NSAssert(NO == success, @"Got error and success from copy");
        completionHandler(error);
        return;
    }
    NSAssert(NO != success, @"Got no error and not succes from copy");

    completionHandler(nil);
}

@end
