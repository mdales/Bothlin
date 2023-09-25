//
//  OSLibraryController.h
//  OldSkool
//
//  Created by Michael Dales on 19/09/2023.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface OSLibraryController : NSObject <NSCollectionViewDelegate, NSCollectionViewDataSource>

- (BOOL)reloadData: (NSError **)error;

- (void)importDirectoryContentsAtURL: (NSURL*)url
                               error: (NSError**)error;

@end

NS_ASSUME_NONNULL_END
