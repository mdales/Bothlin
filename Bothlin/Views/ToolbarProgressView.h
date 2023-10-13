//
//  ToolbarProgressView.h
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 29/09/2023.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface ToolbarProgressView : NSView

@property (nonatomic, readwrite) NSUInteger total;
@property (nonatomic, readwrite) NSUInteger current;

@end

NS_ASSUME_NONNULL_END
