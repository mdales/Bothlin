//
//  LibraryController.h
//  Bothlin
//
//  Created by Michael Dales on 19/09/2023.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@protocol LibraryControllerDelegate <NSObject>

- (void)libraryDidUpdate;

@end


@interface LibraryController : NSObject

@property (nonatomic, weak, readwrite) id<LibraryControllerDelegate> delegate;

- (instancetype)initWithPersistentStore: (NSPersistentStoreCoordinator *)store;

- (void)importURLs: (NSArray<NSURL *> *)urls
          callback: (void (^)(BOOL success, NSError *error)) callback;

@end

NS_ASSUME_NONNULL_END
