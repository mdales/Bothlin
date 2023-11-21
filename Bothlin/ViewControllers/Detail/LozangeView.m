//
//  LozangeView.m
//  Bothlin
//
//  Created by Michael Dales on 19/11/2023.
//

#import "LozangeView.h"

@implementation LozangeView

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    NSRect insetBounds = NSInsetRect(self.bounds, 3, 3);
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:insetBounds xRadius:insetBounds.size.height / 2 yRadius:insetBounds.size.height / 2];
    [[NSColor colorNamed:@"TagColor"
                  bundle:[NSBundle mainBundle]] setFill];
    [path fill];
}

@end
