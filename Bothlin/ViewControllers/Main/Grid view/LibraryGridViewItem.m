//
//  OSLibraryViewItem.m
//  Bothlin
//
//  Created by Michael Dales on 20/09/2023.
//

#import "LibraryGridViewItem.h"

@interface LibraryGridViewItem ()

@end

@implementation LibraryGridViewItem

- (void)viewDidLoad {
    [super viewDidLoad];

    NSClickGestureRecognizer *doubleClickGesture =
    [[NSClickGestureRecognizer alloc] initWithTarget:self
                                              action:@selector(onDoubleClick:)];
    [doubleClickGesture setNumberOfClicksRequired:2];
    [doubleClickGesture setDelaysPrimaryMouseButtonEvents:NO];
    [self.view addGestureRecognizer:doubleClickGesture];
}

- (void)setItem: (Item *)item {
    
}

- (void)setSelected: (BOOL)value {
    [super setSelected: value];
    NSColor *bgColor = value ? [NSColor selectedControlColor] : [NSColor clearColor];
    self.view.layer.backgroundColor = bgColor.CGColor;
}

- (void)onDoubleClick:(NSGestureRecognizer *)sender {
    dispatch_assert_queue(dispatch_get_main_queue());
    [self.delegate gridViewItemWasDoubleClicked: self];
}


@end
