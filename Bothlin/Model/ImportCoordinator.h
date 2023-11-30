//
//  ImportCoordinator.h
//  Bothlin
//
//  Created by Michael Dales on 29/11/2023.
//

#import <Cocoa/Cocoa.h>
#import "ModelCoordinatorDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface ImportCoordinator : NSObject

@property (nonatomic, weak, readwrite) id<ModelCoordinatorDelegate> delegate;

- (instancetype)initWithPersistentStore:(NSPersistentStoreCoordinator * _Nonnull)store
                       storageDirectory:(NSURL *)storageDirectory;

- (instancetype)initWithPersistentStore:(NSPersistentStoreCoordinator * _Nonnull)store
                       storageDirectory:(NSURL *)storageDirectory
                  delegateCallbackQueue:(dispatch_queue_t _Nonnull)delegateUpdateQueue;

- (void)importURLs:(NSSet<NSURL *> *)urls
           toGroup:(NSManagedObjectID * _Nullable)groupID
          callback:(nullable void (^)(BOOL success, NSSet<NSManagedObjectID *> *assets, NSError * _Nullable error))callback;

+ (NSSet<NSURL *> *)removeURLsForUnsupportedTypes:(NSSet<NSURL *> *)urls;

@end

NS_ASSUME_NONNULL_END
