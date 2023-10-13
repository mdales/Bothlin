//
//  ToolbarProgressView.m
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 29/09/2023.
//

#import "ToolbarProgressView.h"

@interface ToolbarProgressView ()

@property (nonatomic, strong, readonly) NSProgressIndicator *progress;
@property (nonatomic, strong, readonly) NSTextField *label;

@end

@implementation ToolbarProgressView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (nil != self) {
        NSRect progressFrame = NSMakeRect(0.0, (frameRect.size.height * 2.0) / 3.0, frameRect.size.width, (frameRect.size.height * 1.0) / 3.0);
        NSProgressIndicator *progress = [[NSProgressIndicator alloc] initWithFrame:progressFrame];
        progress.style = NSProgressIndicatorStyleBar;
        progress.hidden = YES;
        [self addSubview:progress];
        self->_progress = progress;

        NSRect labelFrame = NSMakeRect(0.0, 0.0, frameRect.size.width, (frameRect.size.height * 2.0) / 3.0);
        NSTextField *label = [[NSTextField alloc] initWithFrame:labelFrame];
        label.stringValue = @"Importing n of n";
        label.editable = NO;
        label.alignment = NSTextAlignmentCenter;
        label.bordered = NO;
        label.hidden = YES;
        label.backgroundColor = [NSColor clearColor];
        [self addSubview:label];
        self->_label = label;
    }
    return self;
}

- (void)setProgress:(NSUInteger)current
              total:(NSUInteger)total {
    self.current = current;
    self.total = total;

    self.progress.hidden = current >= total;
    self.label.hidden = current >= total;

    self.label.stringValue = [NSString stringWithFormat:@"Importing %lu of %lu", (unsigned long)current, (unsigned long)total];
    self.progress.maxValue = total;
    self.progress.doubleValue = current;
}

@end
