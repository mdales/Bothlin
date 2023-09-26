//
//  OSLibraryController.m
//  OldSkool
//
//  Created by Michael Dales on 19/09/2023.
//

#import "OSLibraryController.h"
#import "OSLibraryViewItem.h"
#import "AppDelegate.h"
#import "Item+CoreDataClass.h"

@interface OSLibraryController ()

@property (strong, nonatomic, readonly) dispatch_queue_t syncQ;

// Access only on syncQ
@property (strong, nonatomic, readwrite) NSArray<Item *> *contents;

@end

@implementation OSLibraryController

- (instancetype)init {
    self->_syncQ = dispatch_queue_create("com.this.that.OSLibraryController.syncQ", DISPATCH_QUEUE_SERIAL);
    self->_contents = [[NSArray alloc] init];
    return self;
}

- (BOOL)reloadData: (NSError **)error {
    AppDelegate *appDelegate = (AppDelegate *)([NSApplication sharedApplication].delegate);
    NSManagedObjectContext *context = appDelegate.persistentContainer.viewContext;

    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName: @"Item"];
    NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey: @"created"
                                                           ascending: YES];
    [fetchRequest setSortDescriptors: [NSArray arrayWithObject: sort]];

    NSError *innerError = nil;
    NSArray<Item *> *result = [context executeFetchRequest: fetchRequest
                                                     error: &innerError];
    if (nil != innerError) {
        NSAssert(nil == result, @"Got error and fetch results.");
        if (nil != error) {
            *error = innerError;
        }
        return FALSE;
    }
    NSAssert(nil != result, @"Got no error and no fetch results.");

    __weak typeof(self) weakSelf = self;
    dispatch_async(self.syncQ, ^{
        __strong typeof(self) strongSelf = weakSelf;
        strongSelf.contents = result;
    });

    return TRUE;
}

- (void)importDirectoryContentsAtURL: (NSURL*)url
                               error: (NSError**)error {
    NSFileManager *fm = [NSFileManager defaultManager];
    AppDelegate *appDelegate = (AppDelegate *)([NSApplication sharedApplication].delegate);
    NSManagedObjectContext *context = appDelegate.persistentContainer.viewContext;

    NSError *innerError = nil;
    NSArray<NSString *> *files = [fm contentsOfDirectoryAtPath: url.path
                                             error: &innerError];
    if (nil != innerError) {
        if (nil != error) {
            *error = innerError;
        }
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

    innerError = nil;
    BOOL success = [context save: &innerError];
    if (nil != innerError) {
        NSAssert(NO == success, @"Got error and success from saving.");
        if (nil != error) {
            *error = innerError;
        }
        return;
    }
    NSAssert(YES == success, @"Got no success and error from saving.");
}

#pragma mark NSCollectionViewDataSource

- (NSInteger)numberOfSectionsInCollectionView:(NSCollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    __block NSInteger count = 0;
    dispatch_sync(self.syncQ, ^{
        count = self.contents.count;
    });

    return count;
}

- (NSCollectionViewItem *)collectionView:(NSCollectionView *)collectionView itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath {
    __block Item *item = nil;
    dispatch_sync(self.syncQ, ^{
        item = [self.contents objectAtIndex: indexPath.item];
    });
    
    BOOL isStale = NO;
    NSError *error = nil;
    NSURL *path = [NSURL URLByResolvingBookmarkData: item.bookmark
                                            options: NSURLBookmarkResolutionWithSecurityScope
                                      relativeToURL: nil
                                bookmarkDataIsStale: &isStale
                                              error: &error];

    NSCollectionViewItem *viewItem = [collectionView makeItemWithIdentifier: @"OSLibraryViewItem" forIndexPath: indexPath];
    viewItem.textField.stringValue = item.name;

    BOOL canAccess = [path startAccessingSecurityScopedResource];
    if (canAccess) {
        NSImage *image = [[NSImage alloc] initByReferencingURL: path];
        // TODO: fix - if we don't copy the data we have to hold onto the security scope indefinitely
        // but this is clearly wasteful.
        NSImage *copyImage = [[NSImage alloc] initWithData: image.TIFFRepresentation];
        viewItem.imageView.image = copyImage;

        [path stopAccessingSecurityScopedResource];
    } else {
        // TODO: Show damaged preview thingy here
        NSLog(@"Failed to get access");
    }

    return viewItem;
}

#pragma mark NSCollectionViewDelegate

- (void)collectionView:(NSCollectionView *)collectionView didSelectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths {
    for (NSIndexPath *index in indexPaths) {
        NSLog(@"%ld %ld -> selected", (long)index.section, (long)index.item);
    }
}


- (void)collectionView:(NSCollectionView *)collectionView didDeselectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths {
    for (NSIndexPath *index in indexPaths) {
        NSLog(@"%ld %ld -> deselected", (long)index.section, (long)index.item);
    }
}

//- (void)collectionView:(NSCollectionView *)collectionView didChangeItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths toHighlightState:(NSCollectionViewItemHighlightState)highlightState {
//    for (NSIndexPath *index in indexPaths) {
//        NSLog(@"%ld %ld -> %ld", (long)index.section, (long)index.item, (long)highlightState);
//    }
//}

@end
