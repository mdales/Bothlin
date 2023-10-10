//
//  DragTargetView.m
//  Bothlin
//
//  Created by Michael Dales on 07/10/2023.
//

#import "DragTargetView.h"

@implementation DragTargetView

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (nil != self) {
        [self registerForDraggedTypes: @[NSFilenamesPboardType]];
    }
    return self;
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
    return NSDragOperationCopy;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
    if (nil == self.delegate) {
        return NO;
    }
    return [self.delegate dragTargetView:self handleDrag:sender];
}

//- (void)drawRect:(NSRect)dirtyRect {
//    [super drawRect:dirtyRect];
//    NSBezierPath *path = [NSBezierPath bezierPathWithRect:dirtyRect];
//    [[NSColor redColor] setFill];
//    [path fill];
//}

@end
