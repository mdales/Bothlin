//
//  DragTargetView.m
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
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
//    NSLog(@"entered: %lx", sender.draggingSourceOperationMask);
    return (NSDragOperationCopy | NSDragOperationMove) & sender.draggingSourceOperationMask;
}

- (NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)sender {
//    NSLog(@"updated: %lx", sender.draggingSourceOperationMask);
    return (NSDragOperationCopy | NSDragOperationMove) & sender.draggingSourceOperationMask;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
    id<DragTargetViewDelegate> delegate = self.delegate;
    if (nil == delegate) {
        return NO;
    }
    return [delegate dragTargetView:self
                         handleDrag:sender];
}

//- (void)drawRect:(NSRect)dirtyRect {
//    [super drawRect:dirtyRect];
//    NSBezierPath *path = [NSBezierPath bezierPathWithRect:dirtyRect];
//    [[NSColor redColor] setFill];
//    [path fill];
//}

@end
