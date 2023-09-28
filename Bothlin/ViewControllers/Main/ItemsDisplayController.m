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

@property (nonatomic, strong, readonly) GridViewController *gridViewController;
@property (nonatomic, strong, readonly) SingleViewController *singleViewController;

@end

@implementation ItemsDisplayController

- (instancetype)initWithNibName:(NSNibName)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    self->_gridViewController = [[GridViewController alloc] initWithNibName: @"GridViewController" bundle: nil];
    self->_singleViewController = [[SingleViewController alloc] initWithNibName: @"SingleViewController" bundle: nil];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self addChildViewController: self.gridViewController];
    [self.view addSubview: self.gridViewController.view];
}

- (void)reloadData {
    [self.gridViewController reloadData: nil];
}

@end
