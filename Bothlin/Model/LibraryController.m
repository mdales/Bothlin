//
//  LibraryController.m
//  Bothlin
//
//  Created by Michael Dales on 19/09/2023.
//

#import "LibraryController.h"
#import "OSLibraryViewItem.h"
#import "AppDelegate.h"
#import "Item+CoreDataClass.h"
#import "ItemExtension.h"
#import "Helpers.h"
#import "NSURL+SecureAccess.h"

NSString * __nonnull const LibraryControllerErrorDomain = @"com.digitalflapjack.LibraryController";
typedef NS_ENUM(NSInteger, LibraryControllerErrorCode) {
    // code 0 means I made a mistake
    LibraryControllerErrorURLsAreNil = 1,
    LibraryControllerErrorSelfIsNoLongerValid,
    LibraryControllerErrorSecurePathNotAccessible,
    LibraryControllerErrorCouldNotOpenImage,
    LibraryControllerErrorCouldNotGenerateThumbnail,
    LibraryControllerErrorCouldNotCreateThumbnailFile,
    LibraryControllerErrorCouldNotWriteThumbnailFile,
};

@interface LibraryController ()

// Queue used for core data work
@property (strong, nonatomic, readonly) dispatch_queue_t dataQ;
@property (strong, nonatomic, readonly) NSManagedObjectContext *context;

// Queue used for thumbnail processing
@property (strong, nonatomic, readonly) dispatch_queue_t thumbnailWorkerQ;

// Only access on thumbnailWorkerQ
@property (strong, nonatomic, readonly) NSMutableArray<NSManagedObjectID *> *thumbnailTaskList;

@end

@implementation LibraryController

- (instancetype)initWithPersistentStore:(NSPersistentStoreCoordinator *)store {
    self = [super init];
    if (nil != self) {
        self->_dataQ = dispatch_queue_create("com.digitalflapjack.LibraryController.dataQ", DISPATCH_QUEUE_SERIAL);

        NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType: NSPrivateQueueConcurrencyType];
        context.persistentStoreCoordinator = store;
        self->_context = context;

        self->_thumbnailWorkerQ = dispatch_queue_create("com.digitalflapjack.thumbnailWorkerQ", DISPATCH_QUEUE_SERIAL);
        self->_thumbnailTaskList = [NSMutableArray array];
    }
    return self;
}


- (void)importURLs:(NSArray<NSURL *> *)urls
          callback:(void (^)(BOOL success, NSError *error)) callback {
    if (nil == urls) {
        if (nil != callback) {
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                callback(NO, [NSError errorWithDomain: LibraryControllerErrorDomain
                                                 code: LibraryControllerErrorURLsAreNil
                                             userInfo: nil]);
            });
        }
        return;
    }

    // filter out things like .DS_store
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(id _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        NSURL *url = (NSURL*)evaluatedObject;
        NSString *lastPathComponent = [url lastPathComponent];
        NSArray<NSString *> *knownSkip = @[@".DS_Store", @"desktop.ini"];
        NSInteger index = [knownSkip indexOfObject: lastPathComponent];
        return index == NSNotFound;
    }];
    NSArray *filteredURLs = [urls filteredArrayUsingPredicate: predicate];

    if (0 == filteredURLs.count) {
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
                callback(NO, [NSError errorWithDomain: LibraryControllerErrorDomain
                                                 code: LibraryControllerErrorSelfIsNoLongerValid
                                             userInfo: nil]);
            }
            return;
        }
        NSError *error = nil;
        BOOL success = [self innerImportURLs: filteredURLs
                                       error: &error];

        @weakify(self);
        dispatch_async(dispatch_get_main_queue(), ^{
            @strongify(self);
            if (nil == self) {
                return;
            }
            if (nil == self.delegate) {
                return;
            }
            [self.delegate libraryDidUpdate];
        });

        if (nil != callback) {
            callback(success, error);
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
        Item *item = [self.context existingObjectWithID: itemID
                                                  error: &innerError];
        if (nil != innerError) {
            NSAssert(nil == item, @"Got error and item fetching object with ID %@: %@", itemID, innerError.localizedDescription);
            return;
        }
        NSAssert(nil != item, @"Got no error but also no item fetching object with ID %@", itemID);
        
        secureURL = [item decodeSecureURL: &innerError];
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

    NSString *filename = [NSString stringWithFormat: @"%@.png", [[NSUUID UUID] UUIDString]];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSURL *> *paths = [fm URLsForDirectory:NSDocumentDirectory
                                         inDomains:NSUserDomainMask];
    NSAssert(0 < paths.count, @"No document directory found!");
    NSURL *docsDirectory = [paths lastObject];
    NSURL *thumbnailFile = [docsDirectory URLByAppendingPathComponent: filename];
    [secureURL secureAccessWithBlock: ^(NSURL *url, BOOL canAccess) {
        if (NO == canAccess) {
            innerError = [NSError errorWithDomain: LibraryControllerErrorDomain
                                             code: LibraryControllerErrorSecurePathNotAccessible
                                         userInfo: @{@"URL": url, @"ID": itemID}];
            return;
        }
        
        CFURLRef cfurl = (__bridge_retained CFURLRef)url;
        CGImageSourceRef source = CGImageSourceCreateWithURL(cfurl, NULL);
        if (NULL == source) {
            innerError = [NSError errorWithDomain: LibraryControllerErrorDomain
                                             code: LibraryControllerErrorCouldNotOpenImage
                                         userInfo: @{
                @"URL": url,
                @"ID": itemID,
                NSLocalizedDescriptionKey: [NSString stringWithFormat: @"Could not create image source for %@", [url lastPathComponent]]
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
            innerError = [NSError errorWithDomain: LibraryControllerErrorDomain
                                             code: LibraryControllerErrorCouldNotGenerateThumbnail
                                         userInfo: @{
                @"URL": url,
                @"ID": itemID,
                NSLocalizedDescriptionKey: [NSString stringWithFormat: @"Could not create thumbnail for %@", [url lastPathComponent]]
            }];
            CFRelease(source);
            return;
        }

        CFURLRef cfdesturl = (__bridge_retained CFURLRef)thumbnailFile;
        CGImageDestinationRef destination = CGImageDestinationCreateWithURL(cfdesturl, kUTTypePNG, 1, NULL);
        if (NULL == destination) {
            innerError = [NSError errorWithDomain: LibraryControllerErrorDomain
                                             code: LibraryControllerErrorCouldNotCreateThumbnailFile
                                         userInfo: @{
                @"URL": thumbnailFile,
                NSLocalizedDescriptionKey: [NSString stringWithFormat: @"Could not create thumbnail file at %@", [thumbnailFile lastPathComponent]]
            }];
            CGImageRelease(cgImage);
            CFRelease(source);
            return;
        }

        CGImageDestinationAddImage(destination, cgImage, NULL);

        if (!CGImageDestinationFinalize(destination)) {
            innerError = [NSError errorWithDomain: LibraryControllerErrorDomain
                                             code: LibraryControllerErrorCouldNotWriteThumbnailFile
                                         userInfo: @{
                @"URL": thumbnailFile,
                NSLocalizedDescriptionKey: [NSString stringWithFormat: @"Could not write thumbnail file at %@", [thumbnailFile lastPathComponent]]
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
        Item *item = [self.context existingObjectWithID: itemID
                                                  error: &innerError];
        if (nil != innerError) {
            NSAssert(nil == item, @"Got error and item fetching object with ID %@: %@", itemID, innerError.localizedDescription);
            return;
        }
        NSAssert(nil != item, @"Got no error but also no item fetching object with ID %@", itemID);

        item.thumbnailPath = thumbnailFile.path;
        BOOL success = [self.context save: &innerError];
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
            [self.delegate libraryDidUpdate];
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


- (BOOL)innerImportURLs:(NSArray<NSURL *> *)urls
                  error:(NSError **)error {
    if ((nil == urls) || (0 == urls.count)) {
        return YES;
    }
    dispatch_assert_queue(self.dataQ);

    __block NSError *innerError = nil;
    [self.context performBlockAndWait: ^{
        NSArray<Item *> *newItems = [NSArray array];
        for (NSURL *url in urls) {
            NSError *innerError = nil;
            NSSet<Item *> *importeditems = [Item importItemsAtURL: url
                                                        inContext: self.context
                                                            error: &innerError];
            if (nil != innerError) {
                NSAssert(nil == importeditems, @"Got error making new items but still got results");
                return;
            }
            NSAssert(nil != importeditems, @"Got no error adding items, but no result");

            newItems = [newItems arrayByAddingObjectsFromArray: [importeditems allObjects]];
        }

        BOOL success = [self.context obtainPermanentIDsForObjects: newItems
                                                            error: &innerError];
        if (nil != innerError) {
            NSAssert(NO == success, @"Got error and success from obtainPermanentIDsForObjects.");
            return;
        }
        NSAssert(NO != success, @"Got no success and error from obtainPermanentIDsForObjects.");

        for (Item *item in newItems) {
            @weakify(self);
            dispatch_async(self.thumbnailWorkerQ, ^{
                @strongify(self);
                if (nil == self) {
                    return;
                }
                NSError *error = nil;
                [self generateThumbnailForItemWithID: item.objectID
                                               error: &error];
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
                        [self.delegate thumbnailGenerationFailedWithError: error];
                    });
                }
            });
        }
    }];
    if (nil != innerError) {
        if (nil != error) {
            *error = innerError;
        }
        return NO;
    }
    return YES;
}



@end
