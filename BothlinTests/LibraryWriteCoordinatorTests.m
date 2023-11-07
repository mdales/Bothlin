//
//  LibraryWriteCoordinatorTests.m
//  BothlinTests
//
//  Created by Michael Dales on 06/11/2023.
//

#import <XCTest/XCTest.h>

#import "LibraryWriteCoordinator.h"
#import "Group+CoreDataClass.h"

@interface DelegateRecorder : NSObject <LibraryWriteCoordinatorDelegate>

@property (nonatomic, strong, readwrite, nullable) NSDictionary *changeNotificationData;
@property (nonatomic, strong, readwrite, nullable) dispatch_semaphore_t updateSemaphore;

@end

@implementation DelegateRecorder

- (void)libraryWriteCoordinator:(LibraryWriteCoordinator *)libraryWriteCoordinator
                      didUpdate:(NSDictionary *)changeNotificationData {
    self.changeNotificationData = changeNotificationData;
    if (nil != self.updateSemaphore) {
        dispatch_semaphore_signal(self.updateSemaphore);
    }
}

- (void)libraryWriteCoordinator:(LibraryWriteCoordinator *)libraryWriteCoordinator
               thumbnailForItem:(NSManagedObjectID *)objectID
      generationFailedWithError:(NSError *)error {

}

@end


@interface LibraryWriteCoordinatorTests : XCTestCase

@end

@implementation LibraryWriteCoordinatorTests

+ (NSManagedObjectContext *)managedObjectContextForTests {
    static NSManagedObjectModel *model = nil;
    if (!model) {
        model = [NSManagedObjectModel mergedModelFromBundles:[NSBundle allBundles]];
    }

    NSPersistentStoreCoordinator *psc = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
    NSPersistentStore *store = [psc addPersistentStoreWithType:NSInMemoryStoreType configuration:nil URL:nil options:nil error:nil];
    NSAssert(store, @"Should have a store by now");

    NSManagedObjectContext *moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    moc.persistentStoreCoordinator = psc;

    return moc;
}

- (void)testMakeGroup {
    NSManagedObjectContext *moc = [LibraryWriteCoordinatorTests managedObjectContextForTests];
    LibraryWriteCoordinator *library = [[LibraryWriteCoordinator alloc] initWithPersistentStore:moc.persistentStoreCoordinator
                                                                          delegateCallbackQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    DelegateRecorder *delegate = [[DelegateRecorder alloc] init];
    delegate.updateSemaphore = dispatch_semaphore_create(0);
    library.delegate = delegate;

    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"Group"];
    NSError *error = nil;
    NSArray<Group *> *result = [moc executeFetchRequest:fetchRequest
                                                  error:&error];
    NSAssert(nil == error, @"Got unexpected error");
    XCTAssertEqual([result count], 0, @"Expected no groups");

    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __block BOOL innerSuccess = NO;
    __block NSError *innerError = nil;
    [library createGroup:@"Test"
                callback:^(BOOL success, NSError * _Nullable error) {
        innerSuccess = success;
        innerError = error;
        dispatch_semaphore_signal(sem);
    }];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    XCTAssert(innerSuccess, @"Expected success");
    XCTAssertNil(innerError, @"Got unexpected error");

    result = [moc executeFetchRequest:fetchRequest
                                error:&error];
    NSAssert(nil == error, @"Got unexpected error");
    XCTAssertEqual([result count], 1, @"Expected one groups");

    Group *newGroup = [result firstObject];
    XCTAssertEqual([newGroup.name compare:@"Test"], NSOrderedSame, @"Got wrong name for new group");

    dispatch_semaphore_wait(delegate.updateSemaphore, DISPATCH_TIME_FOREVER);
    XCTAssertNotNil(delegate.changeNotificationData, @"Expected delegate to get change data");
    XCTAssertEqual([delegate.changeNotificationData count], 1, @"Expected only inserts");
    NSArray<NSManagedObjectID *> *inserts = delegate.changeNotificationData[NSInsertedObjectsKey];
    XCTAssertNotNil(inserts, @"Expected inserts");
    XCTAssertEqual([inserts count], 1, @"Expected only group insert");
    XCTAssertEqual([inserts firstObject], newGroup.objectID, @"Expected new object's ID");
}


@end
