//
//  ItemExtension.m
//  Bothlin
//
//  Created by Michael Dales on 28/09/2023.
//

#import "ItemExtension.h"

@implementation Item (Helpers)

+ (BOOL)importItemsAtURL: (NSURL *)url
               inContext: (NSManagedObjectContext *)context
                   error: (NSError **)error {
    __block BOOL success = YES;
    __block NSError *innerError = nil;

    [context performBlockAndWait: ^{
        NSFileManager *fm = [NSFileManager defaultManager];
        NSArray<NSString *> *files = [fm contentsOfDirectoryAtPath: url.path
                                                             error: &innerError];
        if (nil != innerError) {
            success = NO;
            return;
        }

        // we have filenames, so now I need full paths
        NSMutableArray<NSURL *> *fullNames = [NSMutableArray arrayWithCapacity: files.count];
        for (NSString* filename in files) {
            NSURL *fullPathURL = [url URLByAppendingPathComponent: filename];
            [fullNames addObject: fullPathURL];
            NSError *error = nil;
            NSData *bookmark = [fullPathURL bookmarkDataWithOptions: NSURLBookmarkCreationSecurityScopeAllowOnlyReadAccess
                                     includingResourceValuesForKeys: nil
                                                      relativeToURL: nil
                                                              error: &error];
            if (nil != error) {
                NSLog(@"failed to make bookmark: %@", error.localizedDescription);
                continue;
            }
            NSAssert(nil != bookmark, @"Bookmark for %@ nil despite no error", fullPathURL);

            Item *item = [NSEntityDescription insertNewObjectForEntityForName: @"Item"
                                                       inManagedObjectContext: context];
            item.name = filename;
            item.path = fullPathURL.path;
            item.bookmark = bookmark;
            item.added = [NSDate now];
            item.type = [filename pathExtension];  // TODO: this should be mime type one day

            NSDictionary<NSFileAttributeKey, id> *attributes = [fm attributesOfItemAtPath: fullPathURL.path
                                                                                    error: &error];
            if (nil != error) {
                NSLog(@"Failed to stat item: %@", error.localizedDescription);
                item.created = [NSDate now];
            } else {
                NSDate *creationDate = [attributes objectForKey: NSFileCreationDate];
                if (nil != creationDate) {
                    item.created = creationDate;
                } else {
                    item.created = [NSDate now];
                }
            }
        }

    }];
    if (nil != error) {
        *error = innerError;
    }
    return success;
}

@end
