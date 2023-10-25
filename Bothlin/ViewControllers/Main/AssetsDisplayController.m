//
//  ItemsDisplayController.m
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 28/09/2023.
//

#import "AssetsDisplayController.h"
#import "GridViewController.h"
#import "SingleViewController.h"

@interface AssetsDisplayController ()

@property (nonatomic, strong, readonly) SingleViewController *singleViewController;
@property (nonatomic, strong, readonly) GridViewController *gridViewController;

@end

@implementation AssetsDisplayController

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

    [self.delegate assetsDisplayController:self
                       viewStyleDidChange:displayStyle];
}

- (void)setAssets:(NSArray<Asset *> *)assets withSelected:(NSIndexPath *)indexPath {
    NSParameterAssert(nil != indexPath);
    dispatch_assert_queue(dispatch_get_main_queue());
    [self.gridViewController setAssets:assets
                          withSelected:indexPath];
    NSInteger index = [indexPath item];
    if (NSNotFound != index) {
        Asset *selectedAsset = [assets objectAtIndex:(NSUInteger)index];
        [self.singleViewController setAssetForDisplay:selectedAsset];
    } else {
        [self.singleViewController setAssetForDisplay:nil];
    }
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
        selectionDidChange:(NSIndexPath *)selectedIndexPath {
    NSParameterAssert(nil != selectedIndexPath);
    [self.delegate assetsDisplayController:self
                       selectionDidChange:selectedIndexPath];
}

- (void)gridViewController:(nonnull GridViewController *)gridViewController
         doubleClickedItem:(nonnull Asset *)item {
    [self.singleViewController setAssetForDisplay: item];
    [self setDisplayStyle:ItemsDisplayStyleSingle];
}

- (void)gridViewController:(GridViewController *)gridViewController 
     didReceiveDroppedURLs:(NSSet<NSURL *> *)URLs {
    dispatch_assert_queue(dispatch_get_main_queue());
    [self.delegate assetsDisplayController:self
                    didReceiveDroppedURLs:URLs];
}

- (BOOL)gridViewController:(GridViewController *)gridViewController item:(Asset *)item wasDraggedOnSidebarItem:(SidebarItem *)sidebarItem {
    if (nil == self.delegate) {
        return NO;
    }
    return [self.delegate assetsDisplayController:self
                                            item:item
                         wasDraggedOnSidebarItem:sidebarItem];
}

#pragma mark - SingleViewControllerDelegate

- (void)singleViewItemWasDoubleClicked:(SingleViewController *)singleViewItem {
    [self setDisplayStyle:ItemsDisplayStyleGrid];
}


@end