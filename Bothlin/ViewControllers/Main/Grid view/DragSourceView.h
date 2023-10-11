//
//  DragSourceView.h
//  Bothlin
//
//  Created by Michael Dales on 11/10/2023.
//

#import <Cocoa/Cocoa.h>

@class DragSourceView;

NS_ASSUME_NONNULL_BEGIN

@protocol DragSourceViewDelegate <NSObject>

- (id<NSPasteboardWriting>)pasteboardWriterForDragSourceView:(DragSourceView *)dragSourceView;
- (NSImage*)draggingImageForDragSourceView:(DragSourceView *)dragSourceView;
- (void)dragSourceView:(DragSourceView *)dragSourceView
            wasClicked:(NSInteger)count;

@end

@interface DragSourceView : NSView <NSDraggingSource>

@property (nonatomic, weak, readwrite) id<DragSourceViewDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
