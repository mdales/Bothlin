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
#import "ItemExtension.h"

@interface OSLibraryController ()

@property (strong, nonatomic, readonly) dispatch_queue_t workQ;
@property (strong, nonatomic, readonly) NSManagedObjectContext *context;

@end

@implementation OSLibraryController

- (instancetype)initWithPersistentStore:(NSPersistentStoreCoordinator *)store {
    self = [super init];
    if (nil != self) {
        self->_workQ = dispatch_queue_create("com.this.that.OSLibraryController.workQ", DISPATCH_QUEUE_SERIAL);

        NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType: NSPrivateQueueConcurrencyType];
        context.persistentStoreCoordinator = store;
        self->_context = context;
    }
    return self;
}

- (void)importURLs: (NSArray<NSURL *> *)urls
          callback: (void (^)(BOOL success, NSError *error)) callback {
    if (nil == urls) {
        return;
    }
    if (0 == urls.count) {
        return;
    }

    __weak typeof(self) weakSelf = self;
    dispatch_async(self.workQ, ^{
        __strong typeof(self) strongSelf = weakSelf;
        NSError *error = nil;
        BOOL success = [strongSelf innerImportURLs: urls
                                             error: &error];
        if (nil != callback) {
            callback(success, error);
        }
    });
}


- (BOOL)innerImportURLs: (NSArray<NSURL *> *)urls
                  error: (NSError **)error {
    NSAssert(nil != urls, @"URLs is nil");
    dispatch_assert_queue(self.workQ);

    for (NSURL *url in urls) {
        NSError *innerError = nil;
        [Item importItemsAtURL: url
                     inContext: self.context
                         error: &innerError];
        if (nil != innerError) {
            if (nil != error) {
                *error = innerError;
            }
            return NO;
        }
    }

    if (YES == self.context.hasChanges) {
        __block BOOL success = YES;
        __block NSError *innerError = nil;
        [self.context performBlockAndWait: ^{
            success = [self.context save: &innerError];
        }];
        if (nil != innerError) {
            NSAssert(NO == success, @"Got error and success from saving.");
            if (nil != error) {
                *error = innerError;
            }
            return NO;
        }
        NSAssert(YES == success, @"Got no success and error from saving.");
    }

    return YES;
}



@end
