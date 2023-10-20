//
//  DragSourceView.h
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 11/10/2023.
//

#import <Cocoa/Cocoa.h>

@class DragSourceView;
@class SidebarItem;

NS_ASSUME_NONNULL_BEGIN

@protocol DragSourceViewDelegate <NSObject>

- (id<NSPasteboardWriting>)pasteboardWriterForDragSourceView:(DragSourceView *)dragSourceView;
- (NSImage*)draggingImageForDragSourceView:(DragSourceView *)dragSourceView;
- (void)dragSourceView:(DragSourceView *)dragSourceView
            wasClicked:(NSInteger)count;
- (BOOL)dragSourceWasDroppedOnSidebar:(SidebarItem *)sidebarItem;

@end

@interface DragSourceView : NSView <NSDraggingSource>

@property (nonatomic, weak, readwrite) id<DragSourceViewDelegate> delegate;

- (BOOL)wasDroppedOnSidebarItem:(SidebarItem *)sidebarItem;

@end

NS_ASSUME_NONNULL_END
