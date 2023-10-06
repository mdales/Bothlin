//
//  SingleViewController.m
//  Bothlin
//
//  Created by Michael Dales on 28/09/2023.
//

#import "SingleViewController.h"
#import "NSURL+SecureAccess.h"
#import "ItemExtension.h"


@interface SingleViewController ()

@property (nonatomic, strong, readwrite) Item *item;

@end

@implementation SingleViewController

- (void)viewDidLoad {
    [super viewDidLoad];

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

- (void)onDoubleClick:(NSGestureRecognizer *)sender {
    dispatch_assert_queue(dispatch_get_main_queue());
    [self.delegate singleViewItemWasDoubleClicked:self];
}

- (void)setItemForDisplay:(Item *)item {
    if (item == self.item) {
        return;
    }

    self.item = item;
    self.imageView.image = nil;

    if (nil != self.view.superview) {
        [self loadImage];
    }
}

- (void)loadImage {
    dispatch_assert_queue(dispatch_get_main_queue());

    if (nil == self.item) {
        return;
    }

    NSError *error = nil;
    NSURL *secureURL = [self.item decodeSecureURL:&error];
    if (nil != error) {
        // TODO: Alert user
        NSLog(@"Failed to get secure URL for %@: %@", self.item, error);
        return;
    }

    [secureURL secureAccessWithBlock:^(NSURL * _Nonnull url, __unused BOOL canAccess) {
        // TODO: shift all this to background queue once working
        NSImage *image = [[NSImage alloc] initByReferencingURL: url];
        BOOL valid = [image isValid];
        if (NO != valid) {
            self.imageView.image = image;
        } else {
            self.imageView.image = [NSImage imageWithSystemSymbolName: @"exclamation.square" accessibilityDescription: nil];
        }
    }];
}

@end
