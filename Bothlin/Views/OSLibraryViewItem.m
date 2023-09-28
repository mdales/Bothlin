//
//  OSLibraryViewItem.m
//  Bothlin
//
//  Created by Michael Dales on 20/09/2023.
//

#import "OSLibraryViewItem.h"

@interface OSLibraryViewItem ()

@end

@implementation OSLibraryViewItem

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}

- (void)setSelected: (BOOL)value {
    [super setSelected: value];
    NSColor *bgColor = value ? [NSColor selectedControlColor] : [NSColor clearColor];
    self.view.layer.backgroundColor = bgColor.CGColor;
}
@end
