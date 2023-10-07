//
//  DragTargetView.h
//  Bothlin
//
//  Created by Michael Dales on 07/10/2023.
//

#import <Cocoa/Cocoa.h>

@class DragTargetView;

NS_ASSUME_NONNULL_BEGIN

@protocol DragTargetViewDelegate <NSObject>

- (BOOL)dragTargetView:(DragTargetView *)dragTargetView
            handleDrag:(id<NSDraggingInfo>)dragOperation;

@end

@interface DragTargetView : NSView

@property (nonatomic, weak, readwrite) id<DragTargetViewDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
