//
//  LibraryWriteCoordinatorTests.m
//  BothlinTests
//
//  Created by Michael Dales on 06/11/2023.
//

#import <XCTest/XCTest.h>

#import "LibraryWriteCoordinator.h"
#import "NSArray+Functional.h"
#import "Asset+CoreDataClass.h"
#import "Group+CoreDataClass.h"
#import "TestModelHelpers.h"

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

- (void)testMakeGroup {
    NSManagedObjectContext *moc = [TestModelHelpers managedObjectContextForTests];
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

- (void)testFavouriteAsset {
    NSManagedObjectContext *moc = [TestModelHelpers managedObjectContextForTests];
    LibraryWriteCoordinator *library = [[LibraryWriteCoordinator alloc] initWithPersistentStore:moc.persistentStoreCoordinator
                                                                          delegateCallbackQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    DelegateRecorder *delegate = [[DelegateRecorder alloc] init];
    delegate.updateSemaphore = dispatch_semaphore_create(0);
    library.delegate = delegate;

    __block NSArray<NSManagedObjectID *> *assetIDs = nil;
    [moc performBlockAndWait:^{
        NSArray<Asset *> *assets = [TestModelHelpers generateAssets:2
                                                          inContext:moc];
        [[assets firstObject] setFavourite:NO];
        [[assets lastObject] setFavourite:YES];
        NSError *error = nil;
        BOOL save = [moc obtainPermanentIDsForObjects:assets
                                                error:&error];
        assetIDs = [assets mapUsingBlock:^id _Nonnull(Asset * _Nonnull asset) { return asset.objectID; }];

        save = [moc save:&error];
    }];

    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __block BOOL innerSuccess = NO;
    __block NSError *innerError = nil;
    __block BOOL innerNewState = NO;
    [library setFavouriteStateOnAssets:[NSSet setWithArray:assetIDs]
                              newState:YES
                              callback:^(BOOL success, NSError * _Nullable error, BOOL newState) {
        innerSuccess = success;
        innerError = error;
        innerNewState = newState;
        dispatch_semaphore_signal(sem);
    }];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    XCTAssertTrue(innerSuccess, @"Expected update to succeed");
    XCTAssertNil(innerError, @"Expected no error: %@", innerError);
    XCTAssertTrue(innerNewState, @"Expected new state to be true");

    dispatch_semaphore_wait(delegate.updateSemaphore, DISPATCH_TIME_FOREVER);
    XCTAssertNotNil(delegate.changeNotificationData, @"Expected delegate to get change data");
    XCTAssertEqual([delegate.changeNotificationData count], 1, @"Expected only inserts");
    NSArray<NSManagedObjectID *> *updates = delegate.changeNotificationData[NSUpdatedObjectsKey];
    XCTAssertNotNil(updates, @"Expected inserts");
    XCTAssertEqual([updates count], 2, @"Expected both assets to update");
    XCTAssertTrue([[NSSet setWithArray:updates] isEqualToSet:[NSSet setWithArray:assetIDs]], @"Expected new updated assets's ID");
}


@end
