//
//  GridViewItemRootView.m
//  Bothlin
//
//  Created by Michael Dales on 31/10/2023.
//

#import "GridViewItemRootView.h"

@implementation GridViewItemRootView

- (NSView *)hitTest:(NSPoint)aPoint
{
    // TODO: This stops child views swallowing the clicks, but I imagine at some point we'll want more
    // controls on this (as we'll have buttons on the thumbnails)
    if (NSPointInRect(aPoint, [self convertRect:[self bounds] toView:[self superview]])) {
        return self;
    } else {
        return nil;
    }
}

-(void)mouseDown:(NSEvent *)theEvent {
    [super mouseDown:theEvent];

    if ([theEvent clickCount] > 1) {
        [self.delegate gridViewRootViewWasDoubleClicked:self];
    }
}

// TODO: This seems neater, but didn't work. Need to dig into why
//- (void)awakeFromNib {
//
//    NSClickGestureRecognizer *doubleClickGesture = [[NSClickGestureRecognizer alloc] initWithTarget:self
//                                                                                             action:@selector(onDoubleClick:)];
//    [doubleClickGesture setNumberOfClicksRequired:2];
//    [doubleClickGesture setDelaysPrimaryMouseButtonEvents:NO];
//    [self addGestureRecognizer:doubleClickGesture];
//}
//
//- (void)onDoubleClick:(NSGestureRecognizer *)sender {
//    [self.delegate gridViewRootViewWasDoubleClicked:self];
//}

@end
