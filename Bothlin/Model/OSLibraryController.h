//
//  OSLibraryController.h
//  OldSkool
//
//  Created by Michael Dales on 19/09/2023.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface OSLibraryController : NSObject

- (instancetype)initWithPersistentStore: (NSPersistentStoreCoordinator *)store;

- (void)importURLs: (NSArray<NSURL *> *)urls
          callback: (void (^)(BOOL success, NSError *error)) callback;


@end

NS_ASSUME_NONNULL_END
