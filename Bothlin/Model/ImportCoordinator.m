//
//  ImportCoordinator.m
//  Bothlin
//
//  Created by Michael Dales on 29/11/2023.
//

#import "ImportCoordinator.h"

#import "Asset+CoreDataClass.h"
#import "Group+CoreDataClass.h"
#import "Tag+CoreDataClass.h"
#import "NSURL+SecureAccess.h"
#import "NSArray+Functional.h"
#import "NSSet+Functional.h"
#import "_EMBCommonSnapMetadata.h"

#import "Helpers.h"

NSErrorDomain __nonnull const ImportCoordinatorErrorDomain = @"com.digitalflapjack.ImportCoordinator";
typedef NS_ERROR_ENUM(ImportCoordinatorErrorDomain, ImportCoordinatorErrorCode) {
    ImportCoordinatorErrorUnknown, // AKA 0, AKA I made a mistake
    ImportCoordinatorErrorNoInfoForSnap,
    ImportCoordinatorErrorNoMetadataForSnap,
};

@interface ImportCoordinator ()

@property (strong, nonatomic, readonly) NSURL *storageDirectory;

// Queue used for core data work
@property (strong, nonatomic, readonly) dispatch_queue_t _Nonnull dataQ;
@property (strong, nonatomic, readonly) NSManagedObjectContext * _Nonnull managedObjectContext;

// Generally should be the mainQ, but for tests we need to redirect this
@property (strong, nonatomic, readonly) dispatch_queue_t _Nonnull updateDelegateQ;

@end

@implementation ImportCoordinator

+ (NSSet<NSURL *> *)removeURLsForUnsupportedTypes:(NSSet<NSURL *> *)urls {
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(id _Nullable evaluatedObject, __unused NSDictionary<NSString *,id> * _Nullable bindings) {
        NSURL *url = (NSURL*)evaluatedObject;
        NSString *lastPathComponent = [url lastPathComponent];
        NSArray<NSString *> *knownSkip = @[@".DS_Store", @"desktop.ini"];
        NSUInteger index = [knownSkip indexOfObject:lastPathComponent];
        return index == NSNotFound;
    }];
    return [urls filteredSetUsingPredicate:predicate];
}

- (instancetype)initWithPersistentStore:(NSPersistentStoreCoordinator * _Nonnull)store
                       storageDirectory:(NSURL *)storageDirectory {
    NSParameterAssert(nil != store);
    NSParameterAssert(nil != storageDirectory);

    return [self initWithPersistentStore:store
                        storageDirectory:storageDirectory
                   delegateCallbackQueue:dispatch_get_main_queue()];
}

- (instancetype)initWithPersistentStore:(NSPersistentStoreCoordinator * _Nonnull)store
                       storageDirectory:(NSURL *)storageDirectory
                  delegateCallbackQueue:(dispatch_queue_t _Nonnull)delegateUpdateQueue {
    NSParameterAssert(nil != store);
    NSParameterAssert(nil != delegateUpdateQueue);

    self = [super init];
    if (nil != self) {
        self->_storageDirectory = storageDirectory;
        self->_dataQ = dispatch_queue_create("com.digitalflapjack.LibraryController.dataQ", DISPATCH_QUEUE_SERIAL);

        NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        context.persistentStoreCoordinator = store;
        self->_managedObjectContext = context;

        self->_updateDelegateQ = delegateUpdateQueue;
    }
    return self;
}

- (void)importURLs:(NSSet<NSURL *> *)urls
           toGroup:(NSManagedObjectID * _Nullable)groupID
          callback:(nullable void (^)(BOOL success, NSSet<NSManagedObjectID *> *assets, NSError * _Nullable error))callback {
    NSParameterAssert(nil != urls);
    dispatch_assert_queue_not(self.dataQ);

    @weakify(self);
    dispatch_async(self.dataQ, ^{
        @strongify(self);
        if (nil == self) {
            return;
        }

        __block NSError *innerError = nil;
        __block NSSet<NSManagedObjectID *> *newAssetIDs = nil;
        [self.managedObjectContext performBlockAndWait:^{
            NSSet<Asset *> *newAssets = [self innerRecursiveImportURLs:urls
                                                               recurse:YES // TODO: This should come from UI/defaults at some point
                                                                 error:&innerError];
            if (nil != innerError) {
                return;
            }
            NSAssert(nil != newAssets, @"Got no error, but no assets also");

            BOOL success = [self.managedObjectContext obtainPermanentIDsForObjects:[newAssets allObjects]
                                                                             error:&innerError];
            if (nil != innerError) {
                NSAssert(NO == success, @"Got error and success from obtainPermanentIDsForObjects.");
                return;
            }
            NSAssert(NO != success, @"Got no success and error from obtainPermanentIDsForObjects.");

            if ((nil != groupID) && ([newAssets count] > 0)) {
                Group *group = [self.managedObjectContext existingObjectWithID:groupID
                                                                         error:&innerError];
                if (nil != innerError) {
                    NSAssert(nil == group, @"Got error and item fetching object with ID %@: %@", groupID, innerError.localizedDescription);
                    return;
                }
                NSAssert(nil != group, @"Got no error but also no item fetching object with ID %@", groupID);

                [group addContains:newAssets];
            }

            // I used to think that getting permanentIDs was equivelent to "Save", as you clearly got
            // a final ID, but it seems it's not committed properly, as problems downstream of here
            // can cause it not to be written. So I'm going to save also
            success = [self.managedObjectContext save:&innerError];
            if (nil != innerError) {
                NSAssert(NO == success, @"Got error and success from save.");
                return;
            }
            NSAssert(NO != success, @"Got no success and error from save.");

            newAssetIDs = [newAssets mapUsingBlock:^id _Nonnull(Asset * _Nonnull asset) { return asset.objectID; }];
        }];

        if (nil != innerError) {
            if (nil != callback) {
                dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                    callback(NO, nil, innerError);
                });
            }
        } else {
            NSAssert(nil != newAssetIDs, @"Got no error, but also no asset IDs");
            if (nil != callback) {
                dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                    callback(YES, newAssetIDs, nil);
                });
            }

            @weakify(self);
            dispatch_async(self.updateDelegateQ, ^{
                @strongify(self);
                if (nil == self) {
                    return;
                }
                [self.delegate modelCoordinator:self
                                      didUpdate:@{NSInsertedObjectsKey:[newAssetIDs allObjects]}];
            });
        }
        
    });
}

- (NSSet<Asset *> *)innerRecursiveImportURLs:(NSSet<NSURL *> *)urls
                                     recurse:(BOOL)recurse
                                       error:(NSError **)error {
    NSParameterAssert(nil != urls);
    dispatch_assert_queue(self.dataQ); // TODO: is this needed here?
    NSLog(@"inner %@", urls);

    NSError *innerError = nil;
    NSMutableSet<Asset *> *assets = [NSMutableSet set];
    NSFileManager *fm = [NSFileManager defaultManager];

    NSSet<NSURL *> *filteredURLs = [ImportCoordinator removeURLsForUnsupportedTypes:urls];
    for (NSURL *url in filteredURLs) {
        // We hwave three options for importing:
        // 1. It's a basic file type we'll import (e.g., an image)
        // 2. It's an Ember snap that is a bundle we import as an asset with extra bits
        // 3. It's a directory, and if permitted we'll recurse into it
        BOOL isDirectory = NO;
        BOOL exists = [fm fileExistsAtPath:[url path]
                               isDirectory:&isDirectory];
        if (NO == exists) {
            NSLog(@"File at %@ doesn't exist apparently", url);
            continue;
        }

        if (NO == isDirectory) {
            // 1. It's a basic file type we'll import (e.g., an image)
            Asset *asset = [self importSimpleAssetAtURL:url
                                                  error:&innerError];
            if (nil != asset) {
                [assets addObject:asset];
            }
        } else {
            if ([[url pathExtension] compare:@"embersnap"] == NSOrderedSame) {
                // 2. It's an Ember snap that is a bundle we import as an asset with extra bits
                Asset *asset = [self importEmberSnapAtURL:url
                                                    error:&innerError];
                if (nil != asset) {
                    [assets addObject:asset];
                }
            } else {
                // 3. It's a directory, and if permitted we'll recurse into it
                if (NO != recurse) {
                    NSArray<NSURL *> *files = [fm contentsOfDirectoryAtURL:url
                                                includingPropertiesForKeys:nil
                                                                   options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                     error:&innerError];
                    if (nil == innerError) {
                        NSAssert(nil != files, @"Got no error, expected files");
                        NSSet<Asset *> *childAssets = [self innerRecursiveImportURLs:[NSSet setWithArray:files]
                                                                             recurse:recurse
                                                                               error:&innerError];
                        if (nil == innerError) {
                            NSAssert(nil != childAssets, @"Got no error, expect assets");
                            [assets addObjectsFromArray:[childAssets allObjects]];
                        }
                    }
                }
            }
        }

        if (nil != innerError) {
            break;
        }
    }

    if (nil != innerError) {
        if (nil != error) {
            *error = innerError;
        }
    }
    return nil == innerError ? [NSSet setWithSet:assets] : nil;
}

- (Asset * _Nullable)importSimpleAssetAtURL:(NSURL *)url
                                      error:(NSError **)error {
    NSParameterAssert(nil != url);
    dispatch_assert_queue(self.dataQ);
    
    NSFileManager *fm = [NSFileManager defaultManager];
    __block NSError *innerError = nil;

    NSString *uuidName = [[NSUUID UUID] UUIDString];
    NSURL *itemDirectory = [self.storageDirectory URLByAppendingPathComponent:uuidName];
    NSURL *rawItemDirectory = [itemDirectory URLByAppendingPathComponent:@"original"];
    BOOL success = [fm createDirectoryAtURL:rawItemDirectory
                withIntermediateDirectories:YES
                                 attributes:nil
                                      error:&innerError];
    if (nil != innerError) {
        NSAssert(NO == success, @"success despite error creating directory %@: %@", itemDirectory, innerError.localizedDescription);
        if (nil != error) {
            *error = innerError;
        }
        return nil;
    }
    NSAssert(NO != success, @"failure but with no error creating directory %@", itemDirectory);

    NSString *filename = [url lastPathComponent];
    NSURL *targetURL = [rawItemDirectory URLByAppendingPathComponent:filename];
    __block BOOL copySuccess = NO;
    // canAccess can still return NO with access if you already had some implicit
    // permission to special locations. Weirdly this does not include the folder
    // in our app's container, which I see YES for in the first call (even though this code
    // will store in our container if I don't ask), but I see NO for Desktop folders for
    // instance but can still access them.
    //
    // As such all I can really do is ignore canAccess and try the copy and deal with any
    // errors that occur instead of using canAccess to pre-empt that.
    [self.storageDirectory secureAccessWithBlock:^(__unused NSURL * _Nonnull secureStorageURL, __unused BOOL canAccess) {
        [url secureAccessWithBlock:^(__unused NSURL * _Nonnull secureFileURL, __unused BOOL canAccess) {
            copySuccess = [fm copyItemAtURL:url
                                      toURL:targetURL
                                      error:&innerError];

        }];
    }];
    if (nil != innerError) {
        NSAssert(NO == copySuccess, @"Copy success despite error %@", innerError.localizedDescription);
        if (nil != error) {
            *error = innerError;
        }
        return nil;
    }
    NSAssert(NO != copySuccess, @"No error but copy failed");

    __block NSData *bookmark = nil;
    [self.storageDirectory secureAccessWithBlock:^(__unused NSURL * _Nonnull secureStorageURL, __unused BOOL canAccess) {
        bookmark = [targetURL bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope
                       includingResourceValuesForKeys:nil
                                        relativeToURL:nil
                                                error:&innerError];
    }];
    if (nil != innerError) {
        NSLog(@"failed to make bookmark: %@", innerError.localizedDescription);
        if (nil != error) {
            *error = innerError;
        }
        return nil;
    }
    NSAssert(nil != bookmark, @"Bookmark for %@ nil despite no error", url);

    Asset *asset = [NSEntityDescription insertNewObjectForEntityForName:@"Asset"
                                                 inManagedObjectContext:self.managedObjectContext];
    asset.name = filename;
    asset.path = targetURL;
    asset.bookmark = bookmark;
    asset.added = [NSDate now];

    // Store the UTType, which is useful for exporting later
    NSString *uttype = (NSString *)CFBridgingRelease(UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)[url pathExtension], NULL));
    asset.type = uttype;

    NSDictionary<NSFileAttributeKey, id> *attributes = [fm attributesOfItemAtPath:url.path
                                                                            error:&innerError];
    if (nil != innerError) {
        NSLog(@"Failed to stat item: %@", innerError.localizedDescription);
        asset.created = [NSDate now];
    } else {
        NSDate *creationDate = [attributes objectForKey:NSFileCreationDate];
        if (nil != creationDate) {
            asset.created = creationDate;
        } else {
            asset.created = [NSDate now];
        }
    }

    return asset;
}

- (Asset * _Nullable)importEmberSnapAtURL:(NSURL *)url
                                    error:(NSError **)error {
    NSParameterAssert(nil != url);
    dispatch_assert_queue(self.dataQ);

    // The info is an archived object of type EMBCommonSnapInfo, rather than a straight plist. Rather than
    // reverse engineer it, I just want the date from this object, so I extract that specifically
    NSDate *creationTime = nil;
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfURL:[url URLByAppendingPathComponent:@"Info.plist"]];
    if (nil != info) {
        id maybeObjects = info[@"$objects"];
        if ((nil != maybeObjects) && [maybeObjects isKindOfClass:[NSArray class]]) {
            NSArray *objects = (NSArray *)maybeObjects;
            if ([objects count] > 2) {
                id maybeTimeInfo = objects[2];
                if ([maybeTimeInfo isKindOfClass:[NSDictionary class]]) {
                    NSDictionary *timeInfo = (NSDictionary *)maybeTimeInfo;
                    id maybeTime = timeInfo[@"NS.time"];
                    if ((nil != maybeTime) && ([maybeTime isKindOfClass:[NSNumber class]])) {
                        NSNumber *time = (NSNumber *)maybeTime;
                        creationTime = [NSDate dateWithTimeIntervalSinceReferenceDate:[time doubleValue]];
                    }
                }
            }
        }
    }
    if (nil == creationTime) {
        if (nil != error) {
            *error = [NSError errorWithDomain:ImportCoordinatorErrorDomain
                                         code:ImportCoordinatorErrorNoInfoForSnap
                                     userInfo:@{@"URL":url}];
        }
        return nil;
    }

    NSData *data = [NSData dataWithContentsOfURL:[url URLByAppendingPathComponent:@"Metadata2.plist"]];
    if (nil == data) {
        if (nil != error) {
            *error = [NSError errorWithDomain:ImportCoordinatorErrorDomain
                                         code:ImportCoordinatorErrorNoMetadataForSnap
                                     userInfo:@{@"URL":url}];
        }
        return nil;
    }
    __block NSError *innerError = nil;
    _EMBCommonSnapMetadata *metadata = [NSKeyedUnarchiver unarchivedObjectOfClass:[_EMBCommonSnapMetadata class]
                                                                         fromData:data
                                                                            error:&innerError];
    if (nil != innerError) {
        if (nil != error) {
            *error = innerError;
        }
        return nil;
    }


    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *targetURL = [self.storageDirectory URLByAppendingPathComponent:[url lastPathComponent]];
    __block BOOL copySuccess = NO;
    // canAccess can still return NO with access if you already had some implicit
    // permission to special locations. Weirdly this does not include the folder
    // in our app's container, which I see YES for in the first call (even though this code
    // will store in our container if I don't ask), but I see NO for Desktop folders for
    // instance but can still access them.
    //
    // As such all I can really do is ignore canAccess and try the copy and deal with any
    // errors that occur instead of using canAccess to pre-empt that.
    [self.storageDirectory secureAccessWithBlock:^(__unused NSURL * _Nonnull secureStorageURL, __unused BOOL canAccess) {
        [url secureAccessWithBlock:^(__unused NSURL * _Nonnull secureFileURL, __unused BOOL canAccess) {
            copySuccess = [fm copyItemAtURL:url
                                      toURL:targetURL
                                      error:&innerError];

        }];
    }];
    if (nil != innerError) {
        NSAssert(NO == copySuccess, @"Copy success despite error %@", innerError.localizedDescription);
        if (nil != error) {
            *error = innerError;
        }
        return nil;
    }
    NSAssert(NO != copySuccess, @"No error but copy failed");

    __block NSData *bookmark = nil;
    NSURL *itemURL = [targetURL URLByAppendingPathComponent:metadata.imageFileName];
    [self.storageDirectory secureAccessWithBlock:^(__unused NSURL * _Nonnull secureStorageURL, __unused BOOL canAccess) {
        bookmark = [itemURL bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope
                     includingResourceValuesForKeys:nil
                                      relativeToURL:nil
                                              error:&innerError];
    }];
    if (nil != innerError) {
        NSLog(@"failed to make bookmark: %@", innerError.localizedDescription);
        if (nil != error) {
            *error = innerError;
        }
        return nil;
    }
    NSAssert(nil != bookmark, @"Bookmark for %@ nil despite no error", url);

    Asset *asset = [NSEntityDescription insertNewObjectForEntityForName:@"Asset"
                                                 inManagedObjectContext:self.managedObjectContext];
    asset.name = metadata.title;
    asset.path = itemURL;
    asset.bookmark = bookmark;
    asset.added = [NSDate now];
    asset.created = creationTime;

    // Store the UTType, which is useful for exporting later
    NSString *uttype = (NSString *)CFBridgingRelease(UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)[itemURL pathExtension], NULL));
    asset.type = uttype;

    // TODO: We should be somehow adding the inserted tags to a ledger to send upstream
    NSSet<Tag *> *tagObjects = [[NSSet setWithArray:metadata.tags] compactMapUsingBlock:^id _Nullable(NSString * _Nonnull rawTag) {
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
            return tag;
        }

        // We hope for a single tag here
        NSAssert([result count] == 1, @"Unexpceted number of tags for %@: %@", rawTag, result);
        return [result firstObject];
    }];
    [asset addTags:tagObjects];

    return asset;
}

@end
