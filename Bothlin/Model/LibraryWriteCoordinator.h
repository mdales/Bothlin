//
//  LibraryController.h
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 19/09/2023.
//

#import <Cocoa/Cocoa.h>

@class LibraryWriteCoordinator;

NS_ASSUME_NONNULL_BEGIN

@protocol LibraryWriteCoordinatorDelegate <NSObject>

- (void)libraryWriteCoordinator:(LibraryWriteCoordinator *)libraryWriteCoordinator
                      didUpdate:(NSDictionary *)changeNotificationData;

- (void)libraryWriteCoordinator:(LibraryWriteCoordinator *)libraryWriteCoordinator
               thumbnailForItem:(NSManagedObjectID *)objectID
      generationFailedWithError:(NSError *)error;

@end


@interface LibraryWriteCoordinator : NSObject

@property (nonatomic, weak, readwrite) id<LibraryWriteCoordinatorDelegate> delegate;

- (instancetype)initWithPersistentStore:(NSPersistentStoreCoordinator * _Nonnull)store;

- (instancetype)initWithPersistentStore:(NSPersistentStoreCoordinator * _Nonnull)store
                  delegateCallbackQueue:(dispatch_queue_t _Nonnull)delegateUpdateQueue;

- (void)importURLs:(NSArray<NSURL *> *)urls
           toGroup:(NSManagedObjectID * _Nullable)groupID
          callback:(nullable void (^)(BOOL success, NSError * _Nullable error))callback;

- (void)generateThumbnailForAssets:(NSSet<NSManagedObjectID *> *)assetIDs;

- (void)generateScannedTextForAssets:(NSSet<NSManagedObjectID *> *)assetIDs;

- (void)createGroup:(NSString *)name
           callback:(nullable void (^)(BOOL success, NSError * _Nullable error))callback;

- (void)setFavouriteStateOnAssets:(NSSet<NSManagedObjectID *> *)assetIDs
                         newState:(BOOL)state
                         callback:(nullable void (^)(BOOL success, NSError * _Nullable error, BOOL newState))callback;

- (void)addAssets:(NSSet<NSManagedObjectID *> *)assetIDs
          toGroup:(NSManagedObjectID *)groupID
         callback:(nullable void (^)(BOOL success, NSError * _Nullable error))callback;

- (void)removeAssets:(NSSet<NSManagedObjectID *> *)assetIDs
           fromGroup:(NSManagedObjectID *)groupID
            callback:(nullable void (^)(BOOL success, NSError * _Nullable error))callback;

- (void)toggleSoftDeleteAssets:(NSSet<NSManagedObjectID *> *)assetIDs
                      callback:(nullable void (^)(BOOL success, NSError * _Nullable error))callback;

- (void)moveDeletedAssetsToTrash:(nullable void (^)(BOOL success, NSError * _Nullable error))callback;

@end

NS_ASSUME_NONNULL_END
