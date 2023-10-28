//
//  DragSourceView.m
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 11/10/2023.
//

#import "DragSourceView.h"
#import "Helpers.h"

const float kDragThreshold = 3.0;

@implementation DragSourceView

- (BOOL)wasDroppedOnSidebarItem:(SidebarItem *)sidebarItem {
    id<DragSourceViewDelegate> delegate = self.delegate;
    if (nil == delegate) {
        return NO;
    }
    return [delegate dragSourceWasDroppedOnSidebar:sidebarItem];
}

- (void)mouseDown:(NSEvent *)event {
    [super mouseDown:event];

//    NSPoint startLocation = [self convertPoint:event.locationInWindow
//                                      fromView:nil];
//    NSEventMask mask = NSEventMaskLeftMouseDragged | NSEventMaskLeftMouseUp;
//
//    @weakify(self);
//    [self.window trackEventsMatchingMask:mask
//                                 timeout:NSEventDurationForever
//                                    mode:NSEventTrackingRunLoopMode
//                                 handler:^(NSEvent * _Nullable event, BOOL * _Nonnull stop) {
//        NSAssert(nil != stop, @"nonnull stop is null");
//        dispatch_assert_queue(dispatch_get_main_queue());
//        @strongify(self);
//        if (nil == self) {
//            return;
//        }
//        if (nil == event) {
//            return;
//        }
//        if (NSEventTypeLeftMouseUp == event.type) {
//            [self.delegate dragSourceView:self
//                               wasClicked:event.clickCount];
//            *stop = YES;
//        } else {
//            NSPoint movedLocation = [self convertPoint:event.locationInWindow
//                                              fromView:nil];
//            if ((fabs(movedLocation.x - startLocation.x) > kDragThreshold) || (fabs(movedLocation.y - startLocation.y) > kDragThreshold)) {
//                *stop = YES;
//                id<DragSourceViewDelegate> delegate = self.delegate;
//                if (nil != delegate) {
//                    id<NSPasteboardWriting> writer = [delegate pasteboardWriterForDragSourceView:self];
//                    NSDraggingItem *draggingItem = [[NSDraggingItem alloc] initWithPasteboardWriter:writer];
//                    [draggingItem setDraggingFrame:[self frame]
//                                          contents:[delegate draggingImageForDragSourceView:self]];
//                    [self beginDraggingSessionWithItems:@[draggingItem]
//                                                  event:event
//                                                 source:self];
//                }
//            }
//        }
//    }];
}

#pragma mark - NSDraggingSource

- (NSDragOperation)draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context {
    return (NSDraggingContextOutsideApplication == context) ? NSDragOperationCopy : NSDragOperationNone;
}

@end
