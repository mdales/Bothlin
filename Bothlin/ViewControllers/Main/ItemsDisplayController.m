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
        self->_displayStyle = ItemsDisplayStyleGrid;
    }
    return self;
}

- (void)setDisplayStyle:(ItemsDisplayStyle)displayStyle {
    dispatch_assert_queue(dispatch_get_main_queue());
    if (displayStyle == self->_displayStyle) {
        return;
    }
    self->_displayStyle = displayStyle;

    NSArray<NSView *> *subviews = [self.view subviews];
    NSAssert(1 >= [subviews count], @"Item display has more childviews than expected");
    NSView *currentSubview = [subviews firstObject];
    
    NSView *intendedView = displayStyle == ItemsDisplayStyleGrid ? self.gridViewController.view : self.singleViewController.view;
    if (currentSubview == intendedView) {
        return;
    }

    [intendedView setFrame:[self.view frame]];

    // TODO: Add photos app like transition animation
    if (displayStyle == ItemsDisplayStyleGrid) {
        [self.view addSubview:intendedView];
        [[currentSubview animator] removeFromSuperview];
    } else {
        [self.view addSubview:intendedView];
        [currentSubview removeFromSuperview];
    }

    [self.delegate itemsDisplayController:self
                       viewStyleDidChange:displayStyle];
}

- (void)reloadData {
    [self.gridViewController reloadData:nil];
}

#pragma mark - View management

- (void)viewDidLoad {
    [super viewDidLoad];

    self.gridViewController.delegate = self;
    self.singleViewController.delegate = self;

    [self addChildViewController:self.gridViewController];
    [self.gridViewController.view setFrame:self.view.frame];

    [self addChildViewController:self.singleViewController];
    [self.singleViewController.view setFrame:self.view.frame];

    NSView *intendedView = self.displayStyle == ItemsDisplayStyleGrid ? self.gridViewController.view : self.singleViewController.view;
    [self.view addSubview:intendedView];
}

- (void)viewDidLayout {
    [super viewDidLayout];
    // I seem to need to do this otherwise the view is the wronng size in the split view.
    [self.gridViewController.view setFrame:self.view.frame];
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
    [self.singleViewController setItemForDisplay: item];
    [self setDisplayStyle:ItemsDisplayStyleSingle];
}

- (void)gridViewController:(GridViewController *)gridViewController 
     didReceiveDroppedURLs:(NSSet<NSURL *> *)URLs {
    dispatch_assert_queue(dispatch_get_main_queue());
    [self.delegate itemsDisplayController:self
                    didReceiveDroppedURLs:URLs];
}

#pragma mark - SingleViewControllerDelegate

- (void)singleViewItemWasDoubleClicked:(SingleViewController *)singleViewItem {
    [self setDisplayStyle:ItemsDisplayStyleGrid];
}


@end
