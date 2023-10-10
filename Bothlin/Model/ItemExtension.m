//
//  ItemExtension.m
//  Bothlin
//
//  Created by Michael Dales on 28/09/2023.
//

#import "ItemExtension.h"
#import "AppDelegate.h"
#import "NSURL+SecureAccess.h"

@implementation Item (Helpers)

+ (NSSet<Item *> *)importItemsAtURL:(NSURL *)url
                          inContext:(NSManagedObjectContext *)context
                              error:(NSError **)error {
    __block NSError *innerError = nil;
    NSMutableSet<Item *> *items = [[NSMutableSet alloc] init];

    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDirectory = NO;
    BOOL exists = [fm fileExistsAtPath:[url path]
                           isDirectory:&isDirectory];
    if (NO == exists) {
        if (nil != error) {
            *error = [NSError errorWithDomain:NSPOSIXErrorDomain
                                         code:ENOENT
                                     userInfo:@{@"URL": url}];
        }
        return nil;
    }

    NSArray<NSURL *> *files = nil;
    if (NO == isDirectory) {
        files = @[url];
    } else {
        files = [fm contentsOfDirectoryAtURL:url
                  includingPropertiesForKeys:nil
                                     options:NSDirectoryEnumerationSkipsHiddenFiles
                                       error:&innerError];
        if (nil != innerError) {
            if (nil != error) {
                *error = innerError;
            }
            return nil;
        }
    }

    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    BOOL usingDefaultStorageLocation = [[userDefaults valueForKey:kUserDefaultsUsingDefaultStorage] boolValue];
    NSData *bookmark = [userDefaults valueForKey:usingDefaultStorageLocation ? kUserDefaultsDefaultStoragePath : kUserDefaultsCustomStoragePath];
    NSAssert(nil != bookmark, @"User defaults are broken: no storage path");
    BOOL isStale = NO;
    NSURL *storageDirectory = [NSURL URLByResolvingBookmarkData:bookmark
                                                        options:NSURLBookmarkResolutionWithSecurityScope
                                                  relativeToURL:nil
                                            bookmarkDataIsStale:&isStale
                                                          error:&innerError];
    if (nil != innerError) {
        NSAssert(nil == storageDirectory, @"Got error and storage directory");
        if (nil != error) {
            *error = innerError;
        }
        return nil;
    }
    NSAssert(nil != storageDirectory, @"Got no error but no storage directory");
    // TODO: ponder what to do if this fails
    NSAssert(NO == isStale, @"Storage directory is stale");

    for (NSURL* fullPathURL in files) {
        BOOL isDirectory = NO;
        BOOL exists = [fm fileExistsAtPath:[fullPathURL path]
                               isDirectory:&isDirectory];
        if (NO == exists) {
            continue;
        }
        if (isDirectory) {
            NSSet<Item *> *children = [Item importItemsAtURL:fullPathURL
                                                   inContext:context
                                                       error:&innerError];
            if (nil != innerError) {
                break;
            }
            [items addObjectsFromArray:[children allObjects]];
            continue;
        }

        // TODO: This code now feels like its in the wrong place as we've grown this factory method
        // at some point we should move the file duplication code and the item creation code into seperate methods.
        NSString *uuidName = [[NSUUID UUID] UUIDString];
        NSString *extension = [fullPathURL pathExtension];
        NSString *storageFilename = [uuidName stringByAppendingPathExtension:extension];
        NSURL *targetURL = [storageDirectory URLByAppendingPathComponent:storageFilename];
        __block BOOL copySuccess = NO;
        // canAccess can still return NO with access if you already had some implicit
        // permission to special locations. Weirdly this does not include the folder
        // in our app's container, which I see YES for in the first call (even though this code
        // will store in our container if I don't ask), but I see NO for Desktop folders for
        // instance but can still access them.
        //
        // As such all I can really do is ignore canAccess and try the copy and deal with any
        // errors that occur instead of using canAccess to pre-empt that.
        [storageDirectory secureAccessWithBlock:^(__unused NSURL * _Nonnull url, __unused BOOL canAccess) {
            [fullPathURL secureAccessWithBlock:^(__unused NSURL * _Nonnull url, __unused BOOL canAccess) {
                copySuccess = [fm copyItemAtURL:fullPathURL
                                          toURL:targetURL
                                          error:&innerError];

            }];
        }];
        if (nil != innerError) {
            NSAssert(NO == copySuccess, @"Copy success despite error");
            break;
        }
        NSAssert(NO != copySuccess, @"No error but copy failed");

        __block NSError *error = nil;
        __block NSData *bookmark = nil;
        [storageDirectory secureAccessWithBlock:^(__unused NSURL * _Nonnull url, __unused BOOL canAccess) {
            bookmark = [targetURL bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope
                           includingResourceValuesForKeys:nil
                                            relativeToURL:nil
                                                    error:&error];
        }];
        if (nil != error) {
            NSLog(@"failed to make bookmark: %@", error.localizedDescription);
            continue;
        }
        NSAssert(nil != bookmark, @"Bookmark for %@ nil despite no error", fullPathURL);

        Item *item = [NSEntityDescription insertNewObjectForEntityForName:@"Item"
                                                   inManagedObjectContext:context];
        item.name = [fullPathURL lastPathComponent];
        item.path = targetURL.path;
        item.bookmark = bookmark;
        item.added = [NSDate now];
        item.type = [fullPathURL pathExtension];  // TODO: this should be mime type one day

        NSDictionary<NSFileAttributeKey, id> *attributes = [fm attributesOfItemAtPath:fullPathURL.path
                                                                                error:&error];
        if (nil != error) {
            NSLog(@"Failed to stat item: %@", error.localizedDescription);
            item.created = [NSDate now];
        } else {
            NSDate *creationDate = [attributes objectForKey:NSFileCreationDate];
            if (nil != creationDate) {
                item.created = creationDate;
            } else {
                item.created = [NSDate now];
            }
        }

        [items addObject:item];
    }

    if (nil != error) {
        *error = innerError;
    }
    return (nil == innerError) ? [NSSet setWithSet:items] : nil;
}


- (NSURL*)decodeSecureURL:(NSError**)error {
    BOOL isStale = NO;
    NSError *innerError = nil;
    NSURL *decoded = [NSURL URLByResolvingBookmarkData:self.bookmark
                                               options:NSURLBookmarkResolutionWithSecurityScope
                                         relativeToURL:nil
                                   bookmarkDataIsStale:&isStale
                                                 error:&innerError];
    if (nil != innerError) {
        NSAssert(nil == decoded, @"Got error decoding secure URL and a result");
        if (nil != error) {
            *error = innerError;
        }
        return nil;
    }
    NSAssert(nil != decoded, @"Got no error and no result");
    if (NO != isStale) {
        if (nil != error) {
            *error = [NSError errorWithDomain:NSPOSIXErrorDomain
                                         code:ESTALE
                                     userInfo:@{
                @"ID": self.objectID,
                @"Path": decoded
            }];
        }
        return nil;
    }
    return decoded;
}

@end
