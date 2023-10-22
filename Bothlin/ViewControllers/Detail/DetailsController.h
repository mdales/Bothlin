//
//  DetailsController.h
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 28/09/2023.
//

#import <Cocoa/Cocoa.h>

@class Asset;

NS_ASSUME_NONNULL_BEGIN

@interface DetailsController : NSViewController <NSOutlineViewDataSource, NSOutlineViewDelegate>

// Only access from mainQ
@property (nonatomic, weak, readwrite) IBOutlet NSOutlineView *detailsView;

- (void)setItemForDisplay:(Asset * _Nullable)item;

@end

NS_ASSUME_NONNULL_END
