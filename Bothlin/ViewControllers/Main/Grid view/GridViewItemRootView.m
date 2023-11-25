//
//  GridViewItemRootView.m
//  Bothlin
//
//  Created by Michael Dales on 31/10/2023.
//

#import "GridViewItemRootView.h"

@implementation GridViewItemRootView

-(void)mouseDown:(NSEvent *)theEvent {
    [super mouseDown:theEvent];

    if ([theEvent clickCount] > 1) {
        [self.delegate gridViewRootViewWasDoubleClicked:self];
    }
}

@end
