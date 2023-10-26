//
//  LibraryController.m
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 19/09/2023.
//

#import <QuickLookThumbnailing/QuickLookThumbnailing.h>

#import "LibraryWriteCoordinator.h"
#import "AppDelegate.h"
#import "Asset+CoreDataClass.h"
#import "Group+CoreDataClass.h"
#import "AssetExtension.h"
#import "Helpers.h"
#import "NSURL+SecureAccess.h"

NSErrorDomain __nonnull const LibraryWriteCoordinatorErrorDomain = @"com.digitalflapjack.LibraryController";
typedef NS_ERROR_ENUM(LibraryWriteCoordinatorErrorDomain, LibraryWriteCoordinatorErrorCode) {
    LibraryWriteCoordinatorErrorUnknown, // AKA 0, AKA I made a mistake
    LibraryWriteCoordinatorErrorURLsAreNil,
    LibraryWriteCoordinatorErrorSelfIsNoLongerValid,
    LibraryWriteCoordinatorErrorSecurePathNotAccessible,

    LibraryWriteCoordinatorErrorCouldNotReadThumbnail,
    LibraryWriteCoordinatorErrorCouldNotCreateImageRep,
    LibraryWriteCoordinatorErrorCouldNotGeneratePNGData,
    LibraryWriteCoordinatorErrorCouldNotWriteThumbnailFile,
};

@interface LibraryWriteCoordinator ()

// Queue used for core data work
@property (strong, nonatomic, readonly) dispatch_queue_t _Nonnull dataQ;
@property (strong, nonatomic, readonly) NSManagedObjectContext * _Nonnull managedObjectContext;

// Queue used for thumbnail processing
@property (strong, nonatomic, readonly) dispatch_queue_t _Nonnull thumbnailWorkerQ;

@end

@implementation LibraryWriteCoordinator

- (instancetype)initWithPersistentStore:(NSPersistentStoreCoordinator * _Nonnull)store {
    NSParameterAssert(nil != store);
    self = [super init];
    if (nil != self) {
        self->_dataQ = dispatch_queue_create("com.digitalflapjack.LibraryController.dataQ", DISPATCH_QUEUE_SERIAL);

        NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        context.persistentStoreCoordinator = store;
        self->_managedObjectContext = context;

        self->_thumbnailWorkerQ = dispatch_queue_create("com.digitalflapjack.thumbnailWorkerQ", DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}


- (void)importURLs:(NSArray<NSURL *> * _Nonnull)urls
          callback:(void (^)(BOOL success, NSError *error)) callback {
    if (nil == urls) {
        if (nil != callback) {
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                callback(NO, [NSError errorWithDomain:LibraryWriteCoordinatorErrorDomain
                                                 code:LibraryWriteCoordinatorErrorURLsAreNil
                                             userInfo:nil]);
            });
        }
        return;
    }

    // filter out things like .DS_store
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(id _Nullable evaluatedObject, __unused NSDictionary<NSString *,id> * _Nullable bindings) {
        NSURL *url = (NSURL*)evaluatedObject;
        NSString *lastPathComponent = [url lastPathComponent];
        NSArray<NSString *> *knownSkip = @[@".DS_Store", @"desktop.ini"];
        NSUInteger index = [knownSkip indexOfObject:lastPathComponent];
        return index == NSNotFound;
    }];
    NSArray *filteredURLs = [urls filteredArrayUsingPredicate:predicate];

    if (0 == [filteredURLs count]) {
        if (nil != callback) {
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                callback(YES, nil);
            });
        }
        return;
    }

    @weakify(self);
    dispatch_async(self.dataQ, ^{
        @strongify(self);
        if (nil == self) {
            if (nil != callback) {
                callback(NO, [NSError errorWithDomain:LibraryWriteCoordinatorErrorDomain
                                                 code:LibraryWriteCoordinatorErrorSelfIsNoLongerValid
                                             userInfo:nil]);
            }
            return;
        }
        NSError *error = nil;
        NSSet<NSManagedObjectID *> *newItemIDs = [self innerImportURLs:filteredURLs
                                                                 error:&error];
        if (nil != error) {
            NSAssert(nil == newItemIDs, @"Got error and new items to insert");
            if (nil != callback) {
                callback(NO, error);
            }
            return;
        }
        NSAssert(nil != newItemIDs, @"Got no error and not new items to insert");

        @weakify(self);
        dispatch_async(dispatch_get_main_queue(), ^{
            @strongify(self);
            if (nil == self) {
                return;
            }
            [self.delegate libraryWriteCoordinator:self
                                         didUpdate:@{NSInsertedObjectsKey: newItemIDs.allObjects}];
        });

        if (nil != callback) {
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                callback(YES, error);
            });
        }
    });
}

- (BOOL)generateQuicklookPreviewForAssetWithID:(NSManagedObjectID *)itemID
                                         error:(NSError **)error {
    NSParameterAssert(nil != itemID);
    dispatch_assert_queue(self.thumbnailWorkerQ);
    dispatch_assert_queue_not(self.dataQ);
    id<LibraryWriteCoordinatorDelegate> delegate = self.delegate;

    __block NSURL *secureURL = nil;
    __block NSError *innerError = nil;
    dispatch_sync(self.dataQ, ^{
        Asset *asset = [self.managedObjectContext existingObjectWithID:itemID
                                                                 error:&innerError];
        if (nil != innerError) {
            NSAssert(nil == asset, @"Got error and item fetching object with ID %@: %@", itemID, innerError.localizedDescription);
            return;
        }
        NSAssert(nil != asset, @"Got no error but also no item fetching object with ID %@", itemID);

        secureURL = [asset decodeSecureURL:&innerError];
        if (nil != innerError) {
            NSAssert(nil == secureURL, @"Got error and value");
            return;
        }
        NSAssert(nil != secureURL, @"Got no error and no value");

    });
    if (nil != innerError) {
        if (nil != error) {
            *error = innerError;
        }
        return NO;
    }
    
    NSString *filename = [NSString stringWithFormat:@"%@-ql.png", [[NSUUID UUID] UUIDString]];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSURL *> *paths = [fm URLsForDirectory:NSDocumentDirectory
                                         inDomains:NSUserDomainMask];
    NSAssert(0 < [paths count], @"No document directory found!");
    NSURL *docsDirectory = [paths lastObject];
    NSURL *thumbnailFile = [docsDirectory URLByAppendingPathComponent:filename];

    [secureURL secureAccessWithBlock: ^(NSURL *url, BOOL canAccess) {
        if (NO == canAccess) {
            innerError = [NSError errorWithDomain:LibraryWriteCoordinatorErrorDomain
                                             code:LibraryWriteCoordinatorErrorSecurePathNotAccessible
                                         userInfo:@{@"URL": url, @"ID": itemID}];
            return;
        }
        QLThumbnailGenerationRequest *qlRequest = [[QLThumbnailGenerationRequest alloc] initWithFileAtURL:secureURL
                                                                                                     size:CGSizeMake(400.0, 400.0)
                                                                                                    scale:2.0
                                                                                      representationTypes:QLThumbnailGenerationRequestRepresentationTypeThumbnail];
        QLThumbnailGenerator *generator = [QLThumbnailGenerator sharedGenerator];
        @weakify(self);
        [generator generateRepresentationsForRequest:qlRequest
                                       updateHandler:^(QLThumbnailRepresentation * _Nullable thumbnail, QLThumbnailRepresentationType type, NSError * _Nullable error) {
            @strongify(self);
            if (nil == self) {
                return;
            }

            NSImage *image = nil;

            if (nil != error) {
                // If quicklook fails to generate a preview, for now fall back to icon if we can
                NSAssert(nil == thumbnail, @"Got error and thumbnail");
                image = [[NSWorkspace sharedWorkspace] iconForFile:[secureURL path]];
                if (nil == error) {
                    // TODO: This should be more about the icon
                    [delegate libraryWriteCoordinator:self
                                     thumbnailForItem:itemID
                            generationFailedWithError:error];
                    return;
                }
            } else {
                NSAssert(nil != thumbnail, @"Got no error and no thumbnail");
                NSAssert(type == QLThumbnailRepresentationTypeThumbnail, @"Asked for thumbnail, got %ld", (long)type);
                image = [thumbnail NSImage];
            }

            // TODO: replace asserts once we have something working
            NSData *tiffData = [image TIFFRepresentation];
            if (nil == tiffData) {
                [delegate libraryWriteCoordinator:self
                                 thumbnailForItem:itemID
                        generationFailedWithError:[NSError errorWithDomain:LibraryWriteCoordinatorErrorDomain
                                                                      code:LibraryWriteCoordinatorErrorCouldNotReadThumbnail
                                                                  userInfo:@{}]];
                return;
            }
            NSBitmapImageRep *imageRep = [[NSBitmapImageRep alloc] initWithData:tiffData];
            if (nil == imageRep) {
                [delegate libraryWriteCoordinator:self
                                 thumbnailForItem:itemID
                        generationFailedWithError:[NSError errorWithDomain:LibraryWriteCoordinatorErrorDomain
                                                                      code:LibraryWriteCoordinatorErrorCouldNotCreateImageRep
                                                                  userInfo:@{}]];
                return;
            }
            NSData *pngData = [imageRep representationUsingType:NSBitmapImageFileTypePNG
                                                     properties:@{}];
            if (nil == pngData) {
                [delegate libraryWriteCoordinator:self
                                 thumbnailForItem:itemID
                        generationFailedWithError:[NSError errorWithDomain:LibraryWriteCoordinatorErrorDomain
                                                                      code:LibraryWriteCoordinatorErrorCouldNotGeneratePNGData
                                                                  userInfo:@{}]];
                return;
            }
            BOOL success = [pngData writeToURL:thumbnailFile
                                    atomically:YES];
            if (NO == success) {
                [delegate libraryWriteCoordinator:self
                                 thumbnailForItem:itemID
                        generationFailedWithError:[NSError errorWithDomain:LibraryWriteCoordinatorErrorDomain
                                                                      code:LibraryWriteCoordinatorErrorCouldNotWriteThumbnailFile
                                                                  userInfo:@{}]];
                return;
            }

            // now we've generated the thumbnail, we should update the record
            dispatch_sync(self.dataQ, ^{
                Asset *asset = [self.managedObjectContext existingObjectWithID:itemID
                                                                         error:&innerError];
                if (nil != innerError) {
                    NSAssert(nil == asset, @"Got error and item fetching object with ID %@: %@", itemID, innerError.localizedDescription);
                    return;
                }
                NSAssert(nil != asset, @"Got no error but also no item fetching object with ID %@", itemID);

                asset.thumbnailPath = thumbnailFile.path;
                BOOL success = [self.managedObjectContext save:&innerError];
                if (nil != innerError) {
                    NSAssert(NO == success, @"Got error and success from saving.");
                    return;
                }
                NSAssert(NO != success, @"Got no error and no success from saving.");

                @weakify(self);
                dispatch_async(dispatch_get_main_queue(), ^{
                    @strongify(self);
                    if (nil == self) {
                        return;
                    }
                    [self.delegate libraryWriteCoordinator:self
                                                 didUpdate:@{NSUpdatedObjectsKey:@[itemID]}];
                });
            });
        }];
    }];
    if (nil != innerError) {
        if (nil != error) {
            *error = innerError;
        }
        return NO;
    }

    return YES;
}

- (NSSet<NSManagedObjectID *> *)innerImportURLs:(NSArray<NSURL *> *)urls
                                          error:(NSError **)error {
    if ((nil == urls) || (0 == [urls count])) {
        return [NSSet set];
    }
    dispatch_assert_queue(self.dataQ);

    __block NSError *innerError = nil;
    __block NSSet<NSManagedObjectID *> *newAssetIDs = nil;
    [self.managedObjectContext performBlockAndWait:^{
        NSArray<Asset *> *newAssets = @[];
        for (NSURL *url in urls) {
            NSSet<Asset *> *importedAssets = [Asset importAssetsAtURL:url
                                                            inContext:self.managedObjectContext
                                                                error:&innerError];
            if (nil != innerError) {
                NSAssert(nil == importedAssets, @"Got error making new assets but still got results");
                return;
            }
            NSAssert(nil != importedAssets, @"Got no error adding assets, but no result");

            newAssets = [newAssets arrayByAddingObjectsFromArray:[importedAssets allObjects]];
        }

        BOOL success = [self.managedObjectContext obtainPermanentIDsForObjects:newAssets
                                                                         error:&innerError];
        if (nil != innerError) {
            NSAssert(NO == success, @"Got error and success from obtainPermanentIDsForObjects.");
            return;
        }
        NSAssert(NO != success, @"Got no success and error from obtainPermanentIDsForObjects.");

        // I used to think that getting permanentIDs was equivelent to "Save", as you clearly got
        // a final ID, but it seems it's not committed properly, as problems downstream of here
        // can cause it not to be written. So I'm going to save also
        success = [self.managedObjectContext save:&innerError];
        if (nil != innerError) {
            NSAssert(NO == success, @"Got error and success from save.");
            return;
        }
        NSAssert(NO != success, @"Got no success and error from save.");

        NSMutableSet<NSManagedObjectID *> *newIDs = [NSMutableSet setWithCapacity:[newAssets count]];
        for (Asset *asset in newAssets) {
            [newIDs addObject:asset.objectID];

            @weakify(self);
            dispatch_async(self.thumbnailWorkerQ, ^{
                @strongify(self);
                if (nil == self) {
                    return;
                }
                NSError *error = nil;
                [self generateQuicklookPreviewForAssetWithID:asset.objectID
                                                       error:&error];
                if (nil != error) {
                    NSLog(@"Error generating thumbnail: %@", error.localizedDescription);
                    @weakify(self)
                    dispatch_async(dispatch_get_main_queue(), ^{
                        @strongify(self)
                        if (nil == self) {
                            return;
                        }
                        [self.delegate libraryWriteCoordinator:self
                                              thumbnailForItem:asset.objectID
                                     generationFailedWithError:error];
                    });
                }
            });
        }

        newAssetIDs = [NSSet setWithSet:newIDs];
    }];
    if (nil != innerError) {
        if (nil != error) {
            *error = innerError;
        }
        return nil;
    }
    NSAssert(nil != newAssetIDs, @"Expected asset ID list");
    return newAssetIDs;
}


- (void)createGroup:(NSString *)name
           callback:(void (^)(BOOL success, NSError *error)) callback {
    dispatch_sync(self.dataQ, ^() {
        __block NSError *error = nil;
        __block BOOL success = NO;
        __block NSManagedObjectID *groupID = nil;
        [self.managedObjectContext performBlockAndWait:^{
            Group *group = [NSEntityDescription insertNewObjectForEntityForName:@"Group"
                                                         inManagedObjectContext:self.managedObjectContext];
            group.name = name;

            success = [self.managedObjectContext obtainPermanentIDsForObjects:@[group]
                                                                        error:&error];
            if ((nil == error) && success) {
                groupID = group.objectID;

                success = [self.managedObjectContext save:&error];
            }
        }];
        if ((nil == error) && success && (nil != groupID)) {
            @weakify(self);
            dispatch_async(dispatch_get_main_queue(), ^{
                @strongify(self);
                if (nil == self) {
                    return;
                }
                [self.delegate libraryWriteCoordinator:self
                                             didUpdate:@{NSInsertedObjectsKey:@[groupID]}];
            });
        }

        if (nil != callback) {
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                callback(success, error);
            });
        }
    });
}

- (void)toggleFavouriteState:(NSManagedObjectID *)assetID
                    callback:(void (^)(BOOL success, NSError *error)) callback {
    dispatch_sync(self.dataQ, ^() {
        __block NSError *error = nil;
        __block BOOL success = NO;
        [self.managedObjectContext performBlockAndWait:^{
            Asset *asset = [self.managedObjectContext existingObjectWithID:assetID
                                                                     error:&error];
            if (nil != error) {
                NSAssert(nil == asset, @"Got error and item fetching object with ID %@: %@", assetID, error.localizedDescription);
                return;
            }
            NSAssert(nil != asset, @"Got no error but also no item fetching object with ID %@", assetID);
            asset.favourite = !asset.favourite;
            success = [self.managedObjectContext save:&error];
        }];
        if ((nil == error) && success) {
            @weakify(self);
            dispatch_async(dispatch_get_main_queue(), ^{
                @strongify(self);
                if (nil == self) {
                    return;
                }
                [self.delegate libraryWriteCoordinator:self
                                             didUpdate:@{NSUpdatedObjectsKey:@[assetID]}];
            });
        }

        if (nil != callback) {
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                callback(success, error);
            });
        }
    });
}

- (void)addAsset:(NSManagedObjectID *)assetID
         toGroup:(NSManagedObjectID *)groupID
        callback:(void (^)(BOOL success, NSError *error)) callback {
    dispatch_sync(self.dataQ, ^() {
        __block NSError *error = nil;
        __block BOOL success = NO;
        [self.managedObjectContext performBlockAndWait:^{
            Asset *asset = [self.managedObjectContext existingObjectWithID:assetID
                                                                     error:&error];
            if (nil != error) {
                NSAssert(nil == asset, @"Got error and item fetching object with ID %@: %@", assetID, error.localizedDescription);
                return;
            }
            NSAssert(nil != asset, @"Got no error but also no item fetching object with ID %@", assetID);

            Group *group = [self.managedObjectContext existingObjectWithID:groupID
                                                                     error:&error];
            if (nil != error) {
                NSAssert(nil == asset, @"Got error and item fetching object with ID %@: %@", groupID, error.localizedDescription);
                return;
            }
            NSAssert(nil != asset, @"Got no error but also no item fetching object with ID %@", groupID);

            [group addContains:[NSSet setWithObject:asset]];

            success = [self.managedObjectContext save:&error];
        }];
        if ((nil == error) && success) {
            @weakify(self);
            dispatch_async(dispatch_get_main_queue(), ^{
                @strongify(self);
                if (nil == self) {
                    return;
                }
                [self.delegate libraryWriteCoordinator:self
                                             didUpdate:@{NSUpdatedObjectsKey:@[assetID, groupID]}];
            });
        }

        if (nil != callback) {
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                callback(success, error);
            });
        }
    });
}


- (void)toggleSoftDeleteAsset:(NSManagedObjectID *)assetID
                     callback:(void (^)(BOOL success, NSError *error)) callback {
    dispatch_sync(self.dataQ, ^() {
        __block NSError *error = nil;
        __block BOOL success = NO;
        [self.managedObjectContext performBlockAndWait:^{
            Asset *asset = [self.managedObjectContext existingObjectWithID:assetID
                                                                     error:&error];
            if (nil != error) {
                NSAssert(nil == asset, @"Got error and item fetching object with ID %@: %@", assetID, error.localizedDescription);
                return;
            }
            NSAssert(nil != asset, @"Got no error but also no item fetching object with ID %@", assetID);

            if (nil == asset.deletedAt) {
                asset.deletedAt = [NSDate now];
            } else {
                asset.deletedAt = nil;
            }

            success = [self.managedObjectContext save:&error];
        }];
        if ((nil == error) && success) {
            @weakify(self);
            dispatch_async(dispatch_get_main_queue(), ^{
                @strongify(self);
                if (nil == self) {
                    return;
                }
                [self.delegate libraryWriteCoordinator:self
                                             didUpdate:@{NSUpdatedObjectsKey:@[assetID]}];
            });
        }

        if (nil != callback) {
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                callback(success, error);
            });
        }
    });
}

@end
