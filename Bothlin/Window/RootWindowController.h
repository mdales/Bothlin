//
//  RootWindowController.h
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 28/09/2023.
//

#import <Cocoa/Cocoa.h>

#import "LibraryController.h"
#import "ItemsDisplayController.h"

NS_ASSUME_NONNULL_BEGIN

@interface RootWindowController : NSWindowController <NSToolbarDelegate, LibraryControllerDelegate, ItemsDisplayControllerDelegate>

- (IBAction)import:(id)sender;

@end

NS_ASSUME_NONNULL_END
