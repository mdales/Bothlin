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

- (void)importURLs:(NSArray<NSURL *> * _Nonnull)urls
          callback:(void (^)(BOOL success, NSError *error)) callback;

- (void)createGroup:(NSString *)name
           callback:(void (^)(BOOL success, NSError *error)) callback;

- (void)toggleFavouriteState:(NSManagedObjectID *)assetID
                    callback:(void (^)(BOOL success, NSError *error)) callback;

- (void)addAsset:(NSManagedObjectID *)assetID
         toGroup:(NSManagedObjectID *)groupID
        callback:(void (^)(BOOL success, NSError *error)) callback;

@end

NS_ASSUME_NONNULL_END
