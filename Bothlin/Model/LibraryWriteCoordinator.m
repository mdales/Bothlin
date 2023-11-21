//
//  LibraryController.m
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 19/09/2023.
//

#import <NaturalLanguage/NaturalLanguage.h>
#import <QuickLookThumbnailing/QuickLookThumbnailing.h>
#import <Vision/Vision.h>

#import "LibraryWriteCoordinator.h"
#import "Asset+CoreDataClass.h"
#import "Group+CoreDataClass.h"
#import "Tag+CoreDataClass.h"
#import "AssetExtension.h"
#import "Helpers.h"
#import "NSURL+SecureAccess.h"
#import "NSArray+Functional.h"
#import "NSSet+Functional.h"
#import "NSManagedObjectContext+helpers.h"

NSErrorDomain __nonnull const LibraryWriteCoordinatorErrorDomain = @"com.digitalflapjack.LibraryController";
typedef NS_ERROR_ENUM(LibraryWriteCoordinatorErrorDomain, LibraryWriteCoordinatorErrorCode) {
    LibraryWriteCoordinatorErrorUnknown, // AKA 0, AKA I made a mistake
    LibraryWriteCoordinatorErrorURLsAreNil,
    LibraryWriteCoordinatorErrorSelfIsNoLongerValid,
    LibraryWriteCoordinatorErrorSecurePathNotAccessible,

    LibraryWriteCoordinatorErrorCouldNotReadThumbnail,
    LibraryWriteCoordinatorErrorCouldNotCreateImageRep,
    LibraryWriteCoordinatorErrorCouldNotLoadAsImage,
    LibraryWriteCoordinatorErrorCouldNotGeneratePNGData,
    LibraryWriteCoordinatorErrorCouldNotWriteThumbnailFile,
};

@interface LibraryWriteCoordinator ()

// Queue used for core data work
@property (strong, nonatomic, readonly) dispatch_queue_t _Nonnull dataQ;
@property (strong, nonatomic, readonly) NSManagedObjectContext * _Nonnull managedObjectContext;

// Generally should be the mainQ, but for tests we need to redirect this
@property (strong, nonatomic, readonly) dispatch_queue_t _Nonnull updateDelegateQ;

// Queue used for thumbnail processing
@property (strong, nonatomic, readonly) dispatch_queue_t _Nonnull thumbnailWorkerQ;

@end

@implementation LibraryWriteCoordinator

- (instancetype)initWithPersistentStore:(NSPersistentStoreCoordinator * _Nonnull)store {
    return [self initWithPersistentStore:store
                   delegateCallbackQueue:dispatch_get_main_queue()];
}

- (instancetype)initWithPersistentStore:(NSPersistentStoreCoordinator * _Nonnull)store
                  delegateCallbackQueue:(dispatch_queue_t _Nonnull)delegateUpdateQueue {
    NSParameterAssert(nil != store);
    NSParameterAssert(nil != delegateUpdateQueue);

    self = [super init];
    if (nil != self) {
        self->_dataQ = dispatch_queue_create("com.digitalflapjack.LibraryController.dataQ", DISPATCH_QUEUE_SERIAL);

        NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        context.persistentStoreCoordinator = store;
        self->_managedObjectContext = context;

        self->_thumbnailWorkerQ = dispatch_queue_create("com.digitalflapjack.thumbnailWorkerQ", DISPATCH_QUEUE_CONCURRENT);
        self->_updateDelegateQ = delegateUpdateQueue;
    }
    return self;
}


- (void)importURLs:(NSArray<NSURL *> *)urls
           toGroup:(NSManagedObjectID * _Nullable)groupID
          callback:(nullable void (^)(BOOL, NSError * _Nullable))callback {
    NSParameterAssert(nil != urls);

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
                                                               toGroup:groupID
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
        dispatch_async(self.updateDelegateQ, ^{
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

- (void)generateThumbnailForAssets:(NSSet<NSManagedObjectID *> *)assetIDs {
    NSParameterAssert(nil != assetIDs);

    @weakify(self);
    for (NSManagedObjectID *assetID in assetIDs) {
        dispatch_async(self.thumbnailWorkerQ, ^{
            @strongify(self);
            if (nil == self) {
                return;
            }
            NSError *error = nil;
            [self generateQuicklookPreviewForAssetWithID:assetID
                                                   error:&error];
            if (nil != error) {
                NSLog(@"Failed to generate thumbnail: %@", error);
            }
        });
    }
}

- (void)generateScannedTextForAssets:(NSSet<NSManagedObjectID *> *)assetIDs {
    NSParameterAssert(nil != assetIDs);

    @weakify(self);
    for (NSManagedObjectID *assetID in assetIDs) {
        dispatch_async(self.thumbnailWorkerQ, ^{
            @strongify(self);
            if (nil == self) {
                return;
            }
            NSError *error = nil;
            [self generateScannedText:assetID
                                error:&error];
            if (nil != error) {
                NSLog(@"Failed to scan text: %@", error);
            }

        });
    }
}


#pragma mark -

- (BOOL)generateScannedText:(NSManagedObjectID *)itemID
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

    __block NSImage* image = nil;
    [secureURL secureAccessWithBlock: ^(NSURL *url, BOOL canAccess) {
        if (NO == canAccess) {
            innerError = [NSError errorWithDomain:LibraryWriteCoordinatorErrorDomain
                                             code:LibraryWriteCoordinatorErrorSecurePathNotAccessible
                                         userInfo:@{@"URL": url, @"ID": itemID}];
            return;
        }

        image = [[NSImage alloc] initByReferencingURL:url];
    }];
    if (nil == image) {
        // TODO: we could error if we know this this was an image type, but otherwise just assume
        // this is success for non-image types
        return YES;
    }

    CGImageRef cgImage = [image CGImageForProposedRect:nil
                                               context:nil
                                                 hints:nil];
    // Surprisingly we can get a NSImage object from non-image files, but this will be nil if it
    // can't open them.
    if (NULL == cgImage) {
        // TODO: we could error if we know this this was an image type, but otherwise just assume
        // this is success for non-image types
        return YES;
    }

    VNRecognizeTextRequest *request = [[VNRecognizeTextRequest alloc] initWithCompletionHandler:^(VNRequest * _Nonnull request, NSError * _Nullable error) {
        if (nil != error) {
            if (nil != delegate) {
                // TODO: Needs own callback
                [delegate libraryWriteCoordinator:self
                                 thumbnailForItem:itemID
                        generationFailedWithError:error];
            }
            return;
        }
        NSMutableSet<NSString *> *foundWords = [NSMutableSet set];
        NSArray<VNObservation *> *observations = request.results;
        for (VNObservation *observation in observations) {
            NSAssert([observation isKindOfClass:[VNRecognizedTextObservation class]], @"Expected text observation");
            NSArray<VNRecognizedText *> *potentialTexts = [(VNRecognizedTextObservation *)observation topCandidates:3];
            NSArray<NSString *> *qualityTexts = [potentialTexts compactMapUsingBlock:^id _Nullable(VNRecognizedText * _Nonnull text) {
                return text.confidence >= 1.0 ? text.string : nil;
            }];

            NLTagger *tagger = [[NLTagger alloc] initWithTagSchemes:@[NLTagSchemeNameTypeOrLexicalClass]];
            for (NSString *string in qualityTexts) {
                [tagger setString:string];
                [tagger enumerateTagsInRange:NSMakeRange(0, [string length] - 1)
                                        unit:NLTokenUnitWord
                                      scheme:NLTagSchemeNameTypeOrLexicalClass
                                     options:NLTaggerOmitWhitespace | NLTaggerOmitPunctuation
                                  usingBlock:^(__unused NLTag  _Nullable tag, NSRange tokenRange, __unused BOOL * _Nonnull stop) {
                    // TODO: Look at using the tag to help further cut out things
                    NSString *substring = [string substringWithRange:tokenRange];
                    [foundWords addObject:[substring lowercaseString]];
                }];
            }
        }

        NSString *searchableStringForDatabase = [[foundWords allObjects] componentsJoinedByString:@" "];
        if ([searchableStringForDatabase length] == 0) {
            return;
        }

        // now we've generated the text summary, we should update the record
        dispatch_sync(self.dataQ, ^{
            NSError *error = nil;
            Asset *asset = [self.managedObjectContext existingObjectWithID:itemID
                                                                     error:&error];
            if (nil != error) {
                NSAssert(nil == asset, @"Got error and item fetching object with ID %@: %@", itemID, innerError.localizedDescription);
                [delegate libraryWriteCoordinator:self
                                 thumbnailForItem:itemID
                        generationFailedWithError:error];
                return;
            }
            NSAssert(nil != asset, @"Got no error but also no item fetching object with ID %@", itemID);

            asset.scannedText = searchableStringForDatabase;
            BOOL success = [self.managedObjectContext save:&error];
            if (nil != error) {
                NSAssert(NO == success, @"Got error and success from saving.");
                [delegate libraryWriteCoordinator:self
                                 thumbnailForItem:itemID
                        generationFailedWithError:error];
                return;
            }
            NSAssert(NO != success, @"Got no error and no success from saving.");

            @weakify(self);
            dispatch_async(self.updateDelegateQ, ^{
                @strongify(self);
                if (nil == self) {
                    return;
                }
                [self.delegate libraryWriteCoordinator:self
                                             didUpdate:@{NSUpdatedObjectsKey:@[itemID]}];
            });
        });

    }];
    [request setRecognitionLevel:VNRequestTextRecognitionLevelAccurate];

    VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCGImage:cgImage
                                                                            options:@{}];
    return [handler performRequests:@[request]
                              error:error];
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
                dispatch_async(self.updateDelegateQ, ^{
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
                                        toGroup:(NSManagedObjectID *)groupID
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

        if ((nil != groupID) && ([newAssets count] > 0)) {
            Group *group = [self.managedObjectContext existingObjectWithID:groupID
                                                                     error:&innerError];
            if (nil != innerError) {
                NSAssert(nil == group, @"Got error and item fetching object with ID %@: %@", groupID, innerError.localizedDescription);
                return;
            }
            NSAssert(nil != group, @"Got no error but also no item fetching object with ID %@", groupID);

            [group addContains:[NSSet setWithArray:newAssets]];
        }

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
                    dispatch_async(self.updateDelegateQ, ^{
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
            dispatch_async(self.thumbnailWorkerQ, ^{
                @strongify(self);
                if (nil == self) {
                    return;
                }
                NSError *error = nil;
                [self generateScannedText:asset.objectID
                                    error:&error];
                if (nil != error) {
                    NSLog(@"Error generating text: %@", error.localizedDescription);
                    @weakify(self)
                    dispatch_async(self.updateDelegateQ, ^{
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
    dispatch_assert_queue_not(self.dataQ);

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
            dispatch_async(self.updateDelegateQ, ^{
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

- (void)setFavouriteStateOnAssets:(NSSet<NSManagedObjectID *> *)assetIDs
                         newState:(BOOL)state
                         callback:(nullable void (^)(BOOL success, NSError * _Nullable error, BOOL newState)) callback {
    dispatch_assert_queue_not(self.dataQ);

    dispatch_sync(self.dataQ, ^() {
        __block NSError *error = nil;
        __block BOOL success = NO;
        [self.managedObjectContext performBlockAndWait:^{
            NSSet<Asset *> *assets = [self.managedObjectContext existingObjectsWithIDs:assetIDs
                                                                                 error:&error];
            if (nil != error) {
                return;
            }

            for (Asset *asset in assets) {
                asset.favourite = state;
            }
            success = [self.managedObjectContext save:&error];
        }];
        if ((nil == error) && success) {
            @weakify(self);
            dispatch_async(self.updateDelegateQ, ^{
                @strongify(self);
                if (nil == self) {
                    return;
                }
                [self.delegate libraryWriteCoordinator:self
                                             didUpdate:@{NSUpdatedObjectsKey:[assetIDs allObjects]}];
            });
        }

        if (nil != callback) {
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                callback(success, error, state);
            });
        }
    });
}

- (void)addAssets:(NSSet<NSManagedObjectID *> *)assetIDs
          toGroup:(NSManagedObjectID *)groupID
         callback:(void (^)(BOOL success, NSError *error)) callback {
    dispatch_assert_queue_not(self.dataQ);

    dispatch_sync(self.dataQ, ^() {
        __block NSError *error = nil;
        __block BOOL success = NO;
        [self.managedObjectContext performBlockAndWait:^{
            NSSet<Asset *> *assets = [self.managedObjectContext existingObjectsWithIDs:assetIDs
                                                                                 error:&error];
            if (nil != error) {
                return;
            }

            Group *group = [self.managedObjectContext existingObjectWithID:groupID
                                                                     error:&error];
            if (nil != error) {
                NSAssert(nil == group, @"Got error and item fetching object with ID %@: %@", groupID, error.localizedDescription);
                return;
            }
            NSAssert(nil != group, @"Got no error but also no group fetching object with ID %@", groupID);

            [group addContains:assets];

            success = [self.managedObjectContext save:&error];
        }];
        if ((nil == error) && success) {
            @weakify(self);
            dispatch_async(self.updateDelegateQ, ^{
                @strongify(self);
                if (nil == self) {
                    return;
                }
                [self.delegate libraryWriteCoordinator:self
                                             didUpdate:@{NSUpdatedObjectsKey:[[assetIDs allObjects] arrayByAddingObject:groupID]}];
            });
        }

        if (nil != callback) {
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                callback(success, error);
            });
        }
    });
}

- (void)removeAssets:(NSSet<NSManagedObjectID *> *)assetIDs
           fromGroup:(NSManagedObjectID *)groupID
            callback:(void (^)(BOOL success, NSError *error)) callback {
    dispatch_assert_queue_not(self.dataQ);

    dispatch_sync(self.dataQ, ^() {
        __block NSError *error = nil;
        __block BOOL success = NO;
        [self.managedObjectContext performBlockAndWait:^{
            NSSet<Asset *> *assets = [self.managedObjectContext existingObjectsWithIDs:assetIDs
                                                                                 error:&error];
            if (nil != error) {
                return;
            }

            Group *group = [self.managedObjectContext existingObjectWithID:groupID
                                                                     error:&error];
            if (nil != error) {
                NSAssert(nil == group, @"Got error and item fetching object with ID %@: %@", groupID, error.localizedDescription);
                return;
            }
            NSAssert(nil != group, @"Got no error but also no group fetching object with ID %@", groupID);

            [group removeContains:assets];

            success = [self.managedObjectContext save:&error];
        }];
        if ((nil == error) && success) {
            @weakify(self);
            dispatch_async(self.updateDelegateQ, ^{
                @strongify(self);
                if (nil == self) {
                    return;
                }
                [self.delegate libraryWriteCoordinator:self
                                             didUpdate:@{NSUpdatedObjectsKey:[[assetIDs allObjects] arrayByAddingObject:groupID]}];
            });
        }

        if (nil != callback) {
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                callback(success, error);
            });
        }
    });
}

- (void)toggleSoftDeleteAssets:(NSSet<NSManagedObjectID *> *)assetIDs
                      callback:(void (^)(BOOL success, NSError *error)) callback {
    dispatch_assert_queue_not(self.dataQ);

    dispatch_sync(self.dataQ, ^() {
        __block NSError *error = nil;
        __block BOOL success = NO;
        [self.managedObjectContext performBlockAndWait:^{
            NSSet<Asset *> *assets = [self.managedObjectContext existingObjectsWithIDs:assetIDs
                                                                                 error:&error];
            if (nil != error) {
                return;
            }

            for (Asset *asset in assets) {
                if (nil == asset.deletedAt) {
                    asset.deletedAt = [NSDate now];
                } else {
                    asset.deletedAt = nil;
                }
            }

            success = [self.managedObjectContext save:&error];
        }];
        if ((nil == error) && success) {
            @weakify(self);
            dispatch_async(self.updateDelegateQ, ^{
                @strongify(self);
                if (nil == self) {
                    return;
                }
                [self.delegate libraryWriteCoordinator:self
                                             didUpdate:@{NSUpdatedObjectsKey:[assetIDs allObjects]}];
            });
        }

        if (nil != callback) {
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                callback(success, error);
            });
        }
    });
}


- (void)moveDeletedAssetsToTrash:(nullable void (^)(BOOL success, NSError * _Nullable error)) callback {
    dispatch_assert_queue_not(self.dataQ);

    dispatch_sync(self.dataQ, ^() {
        __block NSError *error = nil;
        __block BOOL success = NO;
        __block NSArray<NSManagedObjectID *> *deletedItems = nil;
        [self.managedObjectContext performBlockAndWait:^{
            NSFetchRequest *trashReequest = [NSFetchRequest fetchRequestWithEntityName:@"Asset"];
            [trashReequest setPredicate:[NSPredicate predicateWithFormat: @"deletedAt != nil"]];
            NSArray<Asset *> *result = [self.managedObjectContext executeFetchRequest:trashReequest
                                                                                error:&error];
            if (nil != error) {
                NSAssert(nil == result, @"Got error and result!");
                return;
            }
            NSAssert(nil != result, @"Got no error and no result");

            NSArray<NSURL *> *thumbnailPaths = [result compactMapUsingBlock:^id _Nonnull(Asset * _Nonnull asset) {
                if (nil == asset.thumbnailPath) {
                    return nil;
                }
                return [NSURL fileURLWithPath:asset.thumbnailPath];
            }];
            NSArray<NSURL *> *assetPaths = [result mapUsingBlock:^id _Nonnull(Asset * _Nonnull asset) {
                NSAssert(nil != asset.path, @"All assets should have a path!");
                return [NSURL fileURLWithPath:asset.path];
            }];

            NSFileManager *fm = [NSFileManager defaultManager];
            for (Asset *asset in result) {
                [self.managedObjectContext deleteObject:asset];
            }
            success = [self.managedObjectContext save:&error];
            deletedItems = [result mapUsingBlock:^id _Nonnull(Asset * _Nonnull asset) {
                return asset.objectID;
            }];
            if (success) {
                for (NSURL *thumbnailPath in thumbnailPaths) {
                    NSError *innerError = nil;
                    [fm removeItemAtURL:thumbnailPath
                                  error:&innerError];
                    if (nil != innerError) {
                        // Just warn on this failure, accept leaking thumbnails as better than distressing user
                        NSLog(@"Failed to remove thumbnail %@: %@", thumbnailPath, innerError);
                    }
                }
                for (NSURL *path in assetPaths) {
                    NSError *innerError = nil;
                    [fm trashItemAtURL:path
                      resultingItemURL:nil
                                 error:&innerError];
                    if (nil != innerError) {
                        // Just warn on this failure, accept leaking thumbnails as better than distressing user
                        NSLog(@"Failed to remove asset %@: %@", path, innerError);
                    }
                }
            }
        }];
        if ((nil == error) && success) {
            @weakify(self);
            dispatch_async(self.updateDelegateQ, ^{
                @strongify(self);
                if (nil == self) {
                    return;
                }
                [self.delegate libraryWriteCoordinator:self
                                             didUpdate:@{NSDeletedObjectsKey:deletedItems}];
            });
        }

        if (nil != callback) {
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                callback(success, error);
            });
        }
    });
}

- (void)addAssets:(NSSet<NSManagedObjectID *> *)assetIDs
           toTags:(NSSet<NSString *> *)rawTags
         callback:(nullable void (^)(BOOL success, NSError * _Nullable error))callback {
    dispatch_assert_queue_not(self.dataQ);

    // TODO: We should do some cleaning on the rawTags data: removing spaces at either end, splitting ones with commas in, etc.

    dispatch_sync(self.dataQ, ^() {
        __block NSError *error = nil;
        __block BOOL success = NO;
        __block NSArray<NSManagedObjectID *> *insertedTagIDs = nil;
        __block NSArray<NSManagedObjectID *> *updatedTagIDs = @[];
        [self.managedObjectContext performBlockAndWait:^{
            NSSet<Asset *> *assets = [self.managedObjectContext existingObjectsWithIDs:assetIDs
                                                                                 error:&error];
            if (nil != error) {
                return;
            }

            // If we have a tag in any case we pick that up in preference to creating a new
            // instance with a different case
            __block NSSet<Tag *> *insertedTags = [NSSet set];
            NSSet<Tag *> *tags = [rawTags compactMapUsingBlock:^id _Nullable(NSString * _Nonnull rawTag) {
                NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:@"Tag"];
                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name ==[c] %@", rawTag];
                [fetch setPredicate:predicate];

                NSError *error = nil;
                NSArray<Tag *> *result = [self.managedObjectContext executeFetchRequest:fetch
                                                                                  error:&error];
                if (nil != error) {
                    NSAssert(nil == result, @"Got error and result");
                    NSLog(@"Failed to look for %@ as tag: %@", rawTag, error.localizedDescription);
                    return nil;
                }
                NSAssert(nil != result, @"Got no error but not result");

                if (0 == [result count]) {
                    Tag *tag = [NSEntityDescription insertNewObjectForEntityForName:@"Tag"
                                                             inManagedObjectContext:self.managedObjectContext];
                    tag.name = rawTag;
                    insertedTags = [insertedTags setByAddingObject:tag];
                    return tag;
                }

                // We hope for a single tag here
                NSAssert([result count] == 1, @"Unexpceted number of tags for %@: %@", rawTag, result);
                return [result firstObject];
            }];

            if ([insertedTags count] > 0) {
                NSArray<Tag *> *insertedTagsArray = [insertedTags allObjects];
                success = [self.managedObjectContext obtainPermanentIDsForObjects:insertedTagsArray
                                                                            error:&error];
                if (nil != error) {
                    return;
                }
                insertedTagIDs = [insertedTagsArray mapUsingBlock:^id _Nonnull(Tag * _Nonnull tag) { return tag.objectID; }];
            }

            for (Tag *tag in tags) {
                [tag addTags:assets];
            }
            updatedTagIDs = [[tags allObjects] mapUsingBlock:^id _Nonnull(Tag * _Nonnull tag) { return tag.objectID; }];

            success = [self.managedObjectContext save:&error];
        }];
        if ((nil == error) && success) {
            @weakify(self);
            dispatch_async(self.updateDelegateQ, ^{
                @strongify(self);
                if (nil == self) {
                    return;
                }
                NSDictionary *changes = @{NSUpdatedObjectsKey:[[assetIDs allObjects] arrayByAddingObjectsFromArray:updatedTagIDs]};
                if (nil != insertedTagIDs) {
                    NSMutableDictionary *mutableChanges = [NSMutableDictionary dictionaryWithDictionary:changes];
                    mutableChanges[NSInsertedObjectsKey] = insertedTagIDs;
                    changes = [NSDictionary dictionaryWithDictionary:mutableChanges];
                }

                [self.delegate libraryWriteCoordinator:self
                                             didUpdate:changes];
            });
        }

        if (nil != callback) {
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                callback(success, error);
            });
        }
    });
}

- (void)removeTags:(NSSet<NSManagedObjectID *> *)tagIDs
        fromAssets:(NSSet<NSManagedObjectID *> *)assetIDs
          callback:(nullable void (^)(BOOL success, NSError * _Nullable error))callback {
    dispatch_assert_queue_not(self.dataQ);

    dispatch_sync(self.dataQ, ^() {
        __block NSError *error = nil;
        __block BOOL success = NO;
        [self.managedObjectContext performBlockAndWait:^{
            NSSet<Asset *> *assets = [self.managedObjectContext existingObjectsWithIDs:assetIDs
                                                                                 error:&error];
            if (nil != error) {
                return;
            }

            NSSet<Tag *> *tags = [self.managedObjectContext existingObjectsWithIDs:tagIDs
                                                                             error:&error];
            if (nil != error) {
                return;
            }

            for (Tag *tag in tags) {
                [tag removeTags:assets];
            }
            success = [self.managedObjectContext save:&error];
        }];
        if ((nil == error) && success) {
            @weakify(self);
            dispatch_async(self.updateDelegateQ, ^{
                @strongify(self);
                if (nil == self) {
                    return;
                }
                [self.delegate libraryWriteCoordinator:self
                                             didUpdate:@{NSUpdatedObjectsKey:[[assetIDs allObjects] arrayByAddingObjectsFromArray:[tagIDs allObjects]]}];
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
