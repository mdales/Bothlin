//
//  RootWindowController.h
//  Bothlin
//
//  Created by Michael Dales on 28/09/2023.
//

#import <Cocoa/Cocoa.h>

#import "LibraryController.h"

NS_ASSUME_NONNULL_BEGIN

@interface RootWindowController : NSWindowController <NSToolbarDelegate, LibraryControllerDelegate>

- (IBAction)import: (id)sender;

@end

NS_ASSUME_NONNULL_END
