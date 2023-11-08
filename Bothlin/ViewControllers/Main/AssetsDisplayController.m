//
//  ItemsDisplayController.m
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 28/09/2023.
//

#import "AssetsDisplayController.h"
#import "GridViewController.h"
#import "SingleViewController.h"
#import "Helpers.h"

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
    // I did use a presentViewController:animator: with an animator object for this originally
    // and whilst it was tider in code, to hide all the animation code in the animator object, it
    // was messier in state, in that you needed to teach the animator about the grid view and the
    // selected item frame, and that felt messier than <waves hand/> this.

    dispatch_assert_queue(dispatch_get_main_queue());
    if (displayStyle == self->_displayStyle) {
        return;
    }
    self->_displayStyle = displayStyle;

    // work out selected cell
    NSRect activeItemFrame = NSMakeRect(0.0, 0.0, 0.0, 0.0);
    BOOL itemIsOnScreen = [self.gridViewController currentSelectedItemFrame:&activeItemFrame];

    if (displayStyle == ItemsDisplayStyleSingle) {
        if (itemIsOnScreen) {
            self.singleViewController.view.frame = activeItemFrame;
            self.singleViewController.view.alphaValue = 1.0;
            self.singleViewController.view.layerContentsRedrawPolicy = NSViewLayerContentsRedrawDuringViewResize;
        } else {
            self.singleViewController.view.frame = self.view.frame;
            self.singleViewController.view.alphaValue = 0.0;
            self.singleViewController.view.layerContentsRedrawPolicy = NSViewLayerContentsRedrawOnSetNeedsDisplay;
        }

        [self.view addSubview:self.singleViewController.view];

        @weakify(self);
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            // This block is run inline with the calling function, so no need to weakify/strongify
            context.duration = 0.5;
            context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];

            if (itemIsOnScreen) {
                self.singleViewController.view.animator.frame = self.view.frame;;
                self.gridViewController.view.animator.alphaValue = 0.0;
            } else {
                self.singleViewController.view.animator.alphaValue = 1.0;
            }

        } completionHandler:^{
            // This block is invoked async on main thread
            @strongify(self);
            if (nil == self) {
                return;
            }
            [self.gridViewController.view removeFromSuperview];
            self.gridViewController.view.alphaValue = 1.0;
            [self.delegate assetsDisplayController:self
                                viewStyleDidChange:displayStyle];
        }];

    } else {
        [self.view addSubview:self.gridViewController.view
                   positioned:NSWindowBelow
                   relativeTo:self.singleViewController.view];

        if (itemIsOnScreen) {
            self.singleViewController.view.layerContentsRedrawPolicy = NSViewLayerContentsRedrawDuringViewResize;
        } else {
            self.singleViewController.view.layerContentsRedrawPolicy = NSViewLayerContentsRedrawOnSetNeedsDisplay;
        }

        @weakify(self);
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            // This block is run inline with the calling function, so no need to weakify/strongify
            context.duration = 0.5;
            if (itemIsOnScreen) {
                self.singleViewController.view.animator.frame = activeItemFrame;
            } else {
                self.singleViewController.view.animator.alphaValue = 0.0;
            }
        } completionHandler:^{
            // This block is invoked async on main thread
            @strongify(self);
            if (nil == self) {
                return;
            }
            [self.singleViewController.view removeFromSuperview];
            [self.delegate assetsDisplayController:self
                                viewStyleDidChange:displayStyle];
        }];
    }
}

- (void)setAssets:(NSArray<Asset *> *)assets withSelected:(NSSet<NSIndexPath *> *)indexPaths {
    NSParameterAssert(nil != assets);
    NSParameterAssert(nil != indexPaths);
    dispatch_assert_queue(dispatch_get_main_queue());
    [self.gridViewController setAssets:assets
                          withSelected:indexPaths];
    if ([indexPaths count] == 1) {
        NSIndexPath *indexPath = [indexPaths anyObject];
        NSInteger index = [indexPath item];
        if (NSNotFound != index) {
            Asset *selectedAsset = [assets objectAtIndex:(NSUInteger)index];
            [self.singleViewController setAssetForDisplay:selectedAsset];
        } else {
            [self.singleViewController setAssetForDisplay:nil];
        }
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
    [self.gridViewController.view setWantsLayer:YES];

    [self addChildViewController:self.singleViewController];
    [self.singleViewController.view setFrame:self.view.frame];
    [self.singleViewController.view setWantsLayer:YES];

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

- (BOOL)gridViewController:(GridViewController *)gridViewController 
     didReceiveDroppedURLs:(NSSet<NSURL *> *)URLs {
    dispatch_assert_queue(dispatch_get_main_queue());
    id<AssetsDisplayControllerDelegate> delegate = self.delegate;
    if (nil == delegate) {
        return NO;
    }
    return [delegate assetsDisplayController:self
                       didReceiveDroppedURLs:URLs];
}

- (BOOL)gridViewController:(GridViewController *)gridViewController assets:(NSSet<Asset *> *)assets wasDraggedOnSidebarItem:(SidebarItem *)sidebarItem {
    id<AssetsDisplayControllerDelegate> delegate = self.delegate;
    if (nil == delegate) {
        return NO;
    }
    return [delegate assetsDisplayController:self
                                    assets:assets
                     wasDraggedOnSidebarItem:sidebarItem];
}

#pragma mark - SingleViewControllerDelegate

- (void)singleViewItemWasDoubleClicked:(SingleViewController *)singleViewItem {
    [self setDisplayStyle:ItemsDisplayStyleGrid];
}

- (void)singleViewController:(SingleViewController *)singleViewController failedToLoadAsset:(Asset *)asset error:(NSError *)error {
    [self.delegate assetsDisplayController:self
                      failedToDisplayAsset:asset
                                     error:error];
}

@end
