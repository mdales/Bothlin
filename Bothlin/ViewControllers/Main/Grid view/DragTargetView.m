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

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)draggingInfo {
    if (NO != [[draggingInfo draggingSource] isKindOfClass:[NSCollectionView class]]) {
        return NSDragOperationNone;
    }
    return (NSDragOperationCopy | NSDragOperationMove) & draggingInfo.draggingSourceOperationMask;
}

- (NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)draggingInfo {
    if (NO != [[draggingInfo draggingSource] isKindOfClass:[NSCollectionView class]]) {
        return NSDragOperationNone;
    }
    return (NSDragOperationCopy | NSDragOperationMove) & draggingInfo.draggingSourceOperationMask;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)draggingInfo {
    if (NO != [[draggingInfo draggingSource] isKindOfClass:[NSCollectionView class]]) {
        return NSDragOperationNone;
    }
    id<DragTargetViewDelegate> delegate = self.delegate;
    if (nil == delegate) {
        return NO;
    }
    return [delegate dragTargetView:self
                         handleDrag:draggingInfo];
}

//- (void)drawRect:(NSRect)dirtyRect {
//    [super drawRect:dirtyRect];
//    NSBezierPath *path = [NSBezierPath bezierPathWithRect:dirtyRect];
//    [[NSColor redColor] setFill];
//    [path fill];
//}

@end
