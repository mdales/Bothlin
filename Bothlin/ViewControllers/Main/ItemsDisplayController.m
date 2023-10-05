//
//  ItemsDisplayController.m
//  Bothlin
//
//  Created by Michael Dales on 28/09/2023.
//

#import "ItemsDisplayController.h"
#import "GridViewController.h"
#import "SingleViewController.h"

@interface ItemsDisplayController ()

@property (nonatomic, strong, readonly) SingleViewController *singleViewController;

@end

@implementation ItemsDisplayController

- (instancetype)initWithNibName:(NSNibName)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (nil != self) {
        self->_gridViewController = [[GridViewController alloc] initWithNibName:@"GridViewController" bundle:nil];
        self->_singleViewController = [[SingleViewController alloc] initWithNibName:@"SingleViewController" bundle:nil];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self addChildViewController:self.gridViewController];
    [self addChildViewController:self.singleViewController];

    // Start with grid view
    [self.gridViewController.view setFrame:self.view.frame];
    [self.view addSubview:self.gridViewController.view];
}

- (void)viewDidLayout {
    [super viewDidLayout];
    // I seem to need to do this otherwise the view is the wronng size in the split view.
    [self.gridViewController.view setFrame:self.view.frame];
}

- (void)reloadData {
    [self.gridViewController reloadData:nil];
}

- (void)toggleView {
    dispatch_assert_queue(dispatch_get_main_queue());

    NSArray<NSView *> *subviews = [self.view subviews];
    NSAssert(1 == [subviews count], @"Item display has more childviews than expected");
    NSView *currentSubview = [subviews firstObject];

    if (currentSubview == self.gridViewController.view) {
        [self.singleViewController.view setFrame: self.view.frame];
        [self.view addSubview: self.singleViewController.view];
    } else {
        [self.gridViewController.view setFrame:self.view.frame];
        [self.view addSubview:self.gridViewController.view];
    }

    [currentSubview removeFromSuperview];
}

@end
