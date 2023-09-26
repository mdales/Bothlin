//
//  OSRootController.h
//  OldSkool
//
//  Created by Michael Dales on 19/09/2023.
//

#import <AppKit/AppKit.h>

#import "OSLibraryController.h"

NS_ASSUME_NONNULL_BEGIN

@interface OSRootController : NSObject <NSSplitViewDelegate, NSOutlineViewDelegate, NSOutlineViewDataSource>

@property (weak, nonatomic) IBOutlet NSSplitView *splitView;
@property (weak, nonatomic) IBOutlet NSCollectionView *libraryView;
@property (weak, nonatomic) IBOutlet NSOutlineView *outlineView;

- (IBAction)addItem: (id)sender;

@end

NS_ASSUME_NONNULL_END
