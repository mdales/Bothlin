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
@property (nonatomic, strong, readonly) GridViewController *gridViewController;

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

    self.gridViewController.delegate = self;

    [self addChildViewController:self.gridViewController];
    [self.gridViewController.view setFrame:self.view.frame];

    [self addChildViewController:self.singleViewController];
    [self.singleViewController.view setFrame:self.view.frame];

    // Start with grid view
    [self.view addSubview:self.gridViewController.view];
//    [self.view addSubview:self.singleViewController.view];
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
        [self.singleViewController.view setFrame:self.view.frame];
        [self.view addSubview:self.singleViewController.view];
    } else {
        [self.gridViewController.view setFrame:self.view.frame];
        [self.view addSubview:self.gridViewController.view];
    }

    [currentSubview removeFromSuperview];
}

#pragma mark - GridViewControllerDelegate

- (void)gridViewController:(GridViewController *)gridViewController
        selectionDidChange:(Item *)item {
    [self.delegate itemsDisplayController:self
                       selectionDidChange:item];
    [self.singleViewController setItemForDisplay:item];
}

- (void)gridViewController:(nonnull GridViewController *)gridViewController
         doubleClickedItem:(nonnull Item *)item {
}


@end
