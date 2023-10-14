//
//  LibraryController.h
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 19/09/2023.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@protocol LibraryControllerDelegate <NSObject>

- (void)libraryDidUpdate:(NSDictionary *)changeNotificationData;
- (void)thumbnailGenerationFailedWithError:(NSError *)error;

@end


@interface LibraryController : NSObject

@property (nonatomic, weak, readwrite) id<LibraryControllerDelegate> delegate;

- (instancetype)initWithPersistentStore:(NSPersistentStoreCoordinator * _Nonnull)store;

- (void)importURLs:(NSArray<NSURL *> * _Nonnull)urls
          callback:(void (^)(BOOL success, NSError *error)) callback;

- (void)createGroup:(NSString *)name
           callback:(void (^)(BOOL success, NSError *error)) callback;

@end

NS_ASSUME_NONNULL_END
