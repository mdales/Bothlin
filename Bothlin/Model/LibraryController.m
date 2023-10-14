//
//  LibraryController.m
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 19/09/2023.
//

#import "LibraryController.h"
#import "AppDelegate.h"
#import "Item+CoreDataClass.h"
#import "Group+CoreDataClass.h"
#import "ItemExtension.h"
#import "Helpers.h"
#import "NSURL+SecureAccess.h"

NSErrorDomain __nonnull const LibraryControllerErrorDomain = @"com.digitalflapjack.LibraryController";
typedef NS_ERROR_ENUM(LibraryControllerErrorDomain, LibraryControllerErrorCode) {
    LibraryControllerErrorUnknown, // AKA 0, AKA I made a mistake
    LibraryControllerErrorURLsAreNil,
    LibraryControllerErrorSelfIsNoLongerValid,
    LibraryControllerErrorSecurePathNotAccessible,
    LibraryControllerErrorCouldNotOpenImage,
    LibraryControllerErrorCouldNotGenerateThumbnail,
    LibraryControllerErrorCouldNotCreateThumbnailFile,
    LibraryControllerErrorCouldNotWriteThumbnailFile,
};

@interface LibraryController ()

// Queue used for core data work
@property (strong, nonatomic, readonly) dispatch_queue_t _Nonnull dataQ;
@property (strong, nonatomic, readonly) NSManagedObjectContext * _Nonnull managedObjectContext;

// Queue used for thumbnail processing
@property (strong, nonatomic, readonly) dispatch_queue_t _Nonnull thumbnailWorkerQ;

@end

@implementation LibraryController

- (instancetype)initWithPersistentStore:(NSPersistentStoreCoordinator * _Nonnull)store {
    NSAssert(nil != store, @"Null persistent store coordinated passed to init");

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
                callback(NO, [NSError errorWithDomain:LibraryControllerErrorDomain
                                                 code:LibraryControllerErrorURLsAreNil
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
                callback(NO, [NSError errorWithDomain:LibraryControllerErrorDomain
                                                 code:LibraryControllerErrorSelfIsNoLongerValid
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
            if (nil == self.delegate) {
                return;
            }
            [self.delegate libraryDidUpdate:@{NSInsertedObjectsKey: newItemIDs.allObjects}];
        });

        if (nil != callback) {
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                callback(YES, error);
            });
        }
    });
}

- (BOOL)generateThumbnailForItemWithID:(NSManagedObjectID *)itemID
                                 error:(NSError **)error {
    if (nil == itemID) {
        return YES;
    }
    dispatch_assert_queue(self.thumbnailWorkerQ);
    dispatch_assert_queue_not(self.dataQ);

    __block NSURL *secureURL = nil;
    __block NSError *innerError = nil;
    dispatch_sync(self.dataQ, ^{
        Item *item = [self.managedObjectContext existingObjectWithID:itemID
                                                  error:&innerError];
        if (nil != innerError) {
            NSAssert(nil == item, @"Got error and item fetching object with ID %@: %@", itemID, innerError.localizedDescription);
            return;
        }
        NSAssert(nil != item, @"Got no error but also no item fetching object with ID %@", itemID);
        
        secureURL = [item decodeSecureURL:&innerError];
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

    NSString *filename = [NSString stringWithFormat:@"%@.png", [[NSUUID UUID] UUIDString]];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSURL *> *paths = [fm URLsForDirectory:NSDocumentDirectory
                                         inDomains:NSUserDomainMask];
    NSAssert(0 < [paths count], @"No document directory found!");
    NSURL *docsDirectory = [paths lastObject];
    NSURL *thumbnailFile = [docsDirectory URLByAppendingPathComponent:filename];
    [secureURL secureAccessWithBlock: ^(NSURL *url, BOOL canAccess) {
        if (NO == canAccess) {
            innerError = [NSError errorWithDomain:LibraryControllerErrorDomain
                                             code:LibraryControllerErrorSecurePathNotAccessible
                                         userInfo:@{@"URL": url, @"ID": itemID}];
            return;
        }
        
        CFURLRef cfurl = (__bridge_retained CFURLRef)url;
        CGImageSourceRef source = CGImageSourceCreateWithURL(cfurl, NULL);
        if (NULL == source) {
            innerError = [NSError errorWithDomain:LibraryControllerErrorDomain
                                             code:LibraryControllerErrorCouldNotOpenImage
                                         userInfo:@{
                @"URL": url,
                @"ID": itemID,
                NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Could not create image source for %@", [url lastPathComponent]]
            }];
            return;
        }

        size_t index = CGImageSourceGetPrimaryImageIndex(source);

        int imageSize = 400;
        CFNumberRef thumbnailSize = CFNumberCreate(NULL, kCFNumberIntType, &imageSize);
        CFDictionaryRef options = NULL;
        CFStringRef keys[3];
        CFTypeRef values[3];
        keys[0] = kCGImageSourceCreateThumbnailWithTransform;
        values[0] = (CFTypeRef)kCFBooleanTrue;
        keys[1] = kCGImageSourceCreateThumbnailFromImageAlways;
        values[1] = (CFTypeRef)kCFBooleanTrue;
        keys[2] = kCGImageSourceThumbnailMaxPixelSize;
        values[2] = (CFTypeRef)thumbnailSize;
        options = CFDictionaryCreate(NULL, (const void **) keys,
                                       (const void **) values, 2,
                                       &kCFTypeDictionaryKeyCallBacks,
                                       & kCFTypeDictionaryValueCallBacks);
        CGImageRef cgImage = CGImageSourceCreateThumbnailAtIndex(source, index, options);
        CFRelease(options);
        CFRelease(thumbnailSize);

        if (NULL == cgImage) {
            innerError = [NSError errorWithDomain:LibraryControllerErrorDomain
                                             code:LibraryControllerErrorCouldNotGenerateThumbnail
                                         userInfo:@{
                @"URL": url,
                @"ID": itemID,
                NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Could not create thumbnail for %@", [url lastPathComponent]]
            }];
            CFRelease(source);
            return;
        }

        CFURLRef cfdesturl = (__bridge_retained CFURLRef)thumbnailFile;
        CGImageDestinationRef destination = CGImageDestinationCreateWithURL(cfdesturl, kUTTypePNG, 1, NULL);
        if (NULL == destination) {
            innerError = [NSError errorWithDomain:LibraryControllerErrorDomain
                                             code:LibraryControllerErrorCouldNotCreateThumbnailFile
                                         userInfo:@{
                @"URL": thumbnailFile,
                NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Could not create thumbnail file at %@", [thumbnailFile lastPathComponent]]
            }];
            CGImageRelease(cgImage);
            CFRelease(source);
            return;
        }

        CGImageDestinationAddImage(destination, cgImage, NULL);

        if (!CGImageDestinationFinalize(destination)) {
            innerError = [NSError errorWithDomain:LibraryControllerErrorDomain
                                             code:LibraryControllerErrorCouldNotWriteThumbnailFile
                                         userInfo:@{
                @"URL": thumbnailFile,
                NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Could not write thumbnail file at %@", [thumbnailFile lastPathComponent]]
            }];
        }

        CFRelease(destination);
        CGImageRelease(cgImage);
        CFRelease(source);
    }];
    if (nil != innerError) {
        if (nil != error) {
            *error = innerError;
        }
        return NO;
    }

    // now we've generated the thumbnail, we should update the record
    dispatch_sync(self.dataQ, ^{
        Item *item = [self.managedObjectContext existingObjectWithID:itemID
                                                  error:&innerError];
        if (nil != innerError) {
            NSAssert(nil == item, @"Got error and item fetching object with ID %@: %@", itemID, innerError.localizedDescription);
            return;
        }
        NSAssert(nil != item, @"Got no error but also no item fetching object with ID %@", itemID);

        item.thumbnailPath = thumbnailFile.path;
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
            if (nil == self.delegate) {
                return;
            }
            [self.delegate libraryDidUpdate:@{NSUpdatedObjectsKey:@[itemID]}];
        });
    });
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
    __block NSSet<NSManagedObjectID *> *newItemIDs = nil;
    [self.managedObjectContext performBlockAndWait:^{
        NSArray<Item *> *newItems = [NSArray array];
        for (NSURL *url in urls) {
            NSSet<Item *> *importeditems = [Item importItemsAtURL:url
                                                        inContext:self.managedObjectContext
                                                            error:&innerError];
            if (nil != innerError) {
                NSAssert(nil == importeditems, @"Got error making new items but still got results");
                return;
            }
            NSAssert(nil != importeditems, @"Got no error adding items, but no result");

            newItems = [newItems arrayByAddingObjectsFromArray:[importeditems allObjects]];
        }

        BOOL success = [self.managedObjectContext obtainPermanentIDsForObjects:newItems
                                                            error:&innerError];
        if (nil != innerError) {
            NSAssert(NO == success, @"Got error and success from obtainPermanentIDsForObjects.");
            return;
        }
        NSAssert(NO != success, @"Got no success and error from obtainPermanentIDsForObjects.");

        NSMutableSet<NSManagedObjectID *> *newIDs = [NSMutableSet setWithCapacity:[newItems count]];
        for (Item *item in newItems) {
            [newIDs addObject:item.objectID];

            @weakify(self);
            dispatch_async(self.thumbnailWorkerQ, ^{
                @strongify(self);
                if (nil == self) {
                    return;
                }
                NSError *error = nil;
                [self generateThumbnailForItemWithID:item.objectID
                                               error:&error];
                if (nil != error) {
                    NSLog(@"Error generating thumbnail: %@", error.localizedDescription);
                    @weakify(self)
                    dispatch_async(dispatch_get_main_queue(), ^{
                        @strongify(self)
                        if (nil == self) {
                            return;
                        }
                        if (nil == self.delegate) {
                            return;
                        }
                        [self.delegate thumbnailGenerationFailedWithError:error];
                    });
                }
            });
        }

        newItemIDs = [NSSet setWithSet:newIDs];
    }];
    if (nil != innerError) {
        if (nil != error) {
            *error = innerError;
        }
        return nil;
    }
    NSAssert(nil != newItemIDs, @"Expected item ID list");
    return newItemIDs;
}


- (void)createGroup:(NSString *)name
           callback:(void (^)(BOOL success, NSError *error)) callback {
    @weakify(self);
    dispatch_sync(self.dataQ, ^() {
        @strongify(self);
        if (nil == self) {
            if (nil != callback) {
                callback(NO, [NSError errorWithDomain:LibraryControllerErrorDomain
                                                 code:LibraryControllerErrorSelfIsNoLongerValid
                                             userInfo:nil]);
            }
            return;
        }
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
                if (nil == self.delegate) {
                    return;
                }
                [self.delegate libraryDidUpdate:@{NSInsertedObjectsKey:@[groupID]}];
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
