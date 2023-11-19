//
//  LibraryWriteCoordinatorTests.m
//  BothlinTests
//
//  Created by Michael Dales on 06/11/2023.
//

#import <XCTest/XCTest.h>

#import "LibraryWriteCoordinator.h"
#import "NSArray+Functional.h"
#import "NSSet+Functional.h"
#import "Asset+CoreDataClass.h"
#import "Group+CoreDataClass.h"
#import "Tag+CoreDataClass.h"
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

        [moc obtainPermanentIDsForObjects:assets
                                    error:nil];
        assetIDs = [assets mapUsingBlock:^id _Nonnull(Asset * _Nonnull asset) { return asset.objectID; }];

        [moc save:nil];
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
    XCTAssertNotNil(updates, @"Expected updates");
    XCTAssertEqual([updates count], 2, @"Expected both assets to update");
    XCTAssertTrue([[NSSet setWithArray:updates] isEqualToSet:[NSSet setWithArray:assetIDs]], @"Expected new updated assets's ID");

    __block NSArray<NSNumber *> *favourites = nil;
    [moc performBlockAndWait:^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Asset"];
        NSArray<Asset *> *assets = [moc executeFetchRequest:fetch error:nil];
        favourites = [assets mapUsingBlock:^id _Nonnull(Asset * _Nonnull asset) {
            return [NSNumber numberWithBool:asset.favourite];
        }];
    }];
    XCTAssertEqual([favourites count], [assetIDs count], @"Got %ld favourite states, expected %ld", [favourites count], [assetIDs count]);
    for (NSNumber *favourite in favourites) {
        XCTAssertTrue([favourite boolValue], @"All should be favourites");
    }
}

- (void)testAddAssetToGroup {
    NSManagedObjectContext *moc = [TestModelHelpers managedObjectContextForTests];
    LibraryWriteCoordinator *library = [[LibraryWriteCoordinator alloc] initWithPersistentStore:moc.persistentStoreCoordinator
                                                                          delegateCallbackQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    DelegateRecorder *delegate = [[DelegateRecorder alloc] init];
    delegate.updateSemaphore = dispatch_semaphore_create(0);
    library.delegate = delegate;

    __block NSArray<NSManagedObjectID *> *assetIDs = nil;
    __block NSManagedObjectID *groupID = nil;
    [moc performBlockAndWait:^{
        NSArray<Asset *> *assets = [TestModelHelpers generateAssets:2
                                                          inContext:moc];
        Group *group = [[TestModelHelpers generateGroups:1
                                               inContext:moc] firstObject];

        [moc obtainPermanentIDsForObjects:assets
                                    error:nil];
        assetIDs = [assets mapUsingBlock:^id _Nonnull(Asset * _Nonnull asset) { return asset.objectID; }];

        [moc obtainPermanentIDsForObjects:[NSArray arrayWithObject:group]
                                    error:nil];
        groupID = group.objectID;

        [moc save:nil];
    }];

    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __block BOOL innerSuccess = NO;
    __block NSError *innerError = nil;
    [library addAssets:[NSSet setWithObject:[assetIDs firstObject]]
               toGroup:groupID
              callback:^(BOOL success, NSError * _Nullable error) {
        innerSuccess = success;
        innerError = error;
        dispatch_semaphore_signal(sem);
    }];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    XCTAssertTrue(innerSuccess, @"Expected update to succeed");
    XCTAssertNil(innerError, @"Expected no error: %@", innerError);

    dispatch_semaphore_wait(delegate.updateSemaphore, DISPATCH_TIME_FOREVER);
    XCTAssertNotNil(delegate.changeNotificationData, @"Expected delegate to get change data");
    XCTAssertEqual([delegate.changeNotificationData count], 1, @"Expected one update type");

    NSArray<NSManagedObjectID *> *updates = delegate.changeNotificationData[NSUpdatedObjectsKey];
    XCTAssertNotNil(updates, @"Expected updates");
    XCTAssertEqual([updates count], 2, @"Expected both asset and group to update");
    XCTAssertTrue([[NSSet setWithArray:updates] containsObject:groupID], @"Expected group in update");
    XCTAssertTrue([[NSSet setWithArray:updates] containsObject:[assetIDs firstObject]], @"Expected first asset in update");

    [NSManagedObjectContext mergeChangesFromRemoteContextSave:delegate.changeNotificationData
                                                 intoContexts:@[moc]];

    __block NSSet<NSManagedObjectID *> *groupMemberIDs = nil;
    [moc performBlockAndWait:^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Group"];
        NSArray<Group *> *groups = [moc executeFetchRequest:fetch error:nil];
        groupMemberIDs = [[groups firstObject].contains mapUsingBlock:^id _Nonnull(Asset * _Nonnull asset) {
            return asset.objectID;
        }];
    }];
    XCTAssertEqual([groupMemberIDs count], 1, @"Should only be one item in group");
    XCTAssertEqual([groupMemberIDs anyObject], [assetIDs firstObject], @"Wrong asset in group");
}

- (void)testRemoveAssetFromGroup {
    NSManagedObjectContext *moc = [TestModelHelpers managedObjectContextForTests];
    LibraryWriteCoordinator *library = [[LibraryWriteCoordinator alloc] initWithPersistentStore:moc.persistentStoreCoordinator
                                                                          delegateCallbackQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    DelegateRecorder *delegate = [[DelegateRecorder alloc] init];
    delegate.updateSemaphore = dispatch_semaphore_create(0);
    library.delegate = delegate;

    __block NSArray<NSManagedObjectID *> *assetIDs = nil;
    __block NSManagedObjectID *groupID = nil;
    [moc performBlockAndWait:^{
        NSArray<Asset *> *assets = [TestModelHelpers generateAssets:2
                                                          inContext:moc];
        Group *group = [[TestModelHelpers generateGroups:1
                                               inContext:moc] firstObject];
        group.contains = [NSSet setWithArray:assets];

        [moc obtainPermanentIDsForObjects:assets
                                    error:nil];
        assetIDs = [assets mapUsingBlock:^id _Nonnull(Asset * _Nonnull asset) { return asset.objectID; }];

        [moc obtainPermanentIDsForObjects:[NSArray arrayWithObject:group]
                                    error:nil];
        groupID = group.objectID;

        [moc save:nil];
    }];

    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __block BOOL innerSuccess = NO;
    __block NSError *innerError = nil;
    [library removeAssets:[NSSet setWithObject:[assetIDs firstObject]]
                fromGroup:groupID
                 callback:^(BOOL success, NSError * _Nullable error) {
        innerSuccess = success;
        innerError = error;
        dispatch_semaphore_signal(sem);
    }];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    XCTAssertTrue(innerSuccess, @"Expected update to succeed");
    XCTAssertNil(innerError, @"Expected no error: %@", innerError);

    dispatch_semaphore_wait(delegate.updateSemaphore, DISPATCH_TIME_FOREVER);
    XCTAssertNotNil(delegate.changeNotificationData, @"Expected delegate to get change data");
    XCTAssertEqual([delegate.changeNotificationData count], 1, @"Expected one update type");

    NSArray<NSManagedObjectID *> *updates = delegate.changeNotificationData[NSUpdatedObjectsKey];
    XCTAssertNotNil(updates, @"Expected updates");
    XCTAssertEqual([updates count], 2, @"Expected both asset and group to update");
    XCTAssertTrue([[NSSet setWithArray:updates] containsObject:groupID], @"Expected group in update");
    XCTAssertTrue([[NSSet setWithArray:updates] containsObject:[assetIDs firstObject]], @"Expected first asset in update");

    [NSManagedObjectContext mergeChangesFromRemoteContextSave:delegate.changeNotificationData
                                                 intoContexts:@[moc]];

    __block NSSet<NSManagedObjectID *> *groupMemberIDs = nil;
    [moc performBlockAndWait:^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Group"];
        NSArray<Group *> *groups = [moc executeFetchRequest:fetch error:nil];
        groupMemberIDs = [[groups firstObject].contains mapUsingBlock:^id _Nonnull(Asset * _Nonnull asset) {
            return asset.objectID;
        }];
    }];
    XCTAssertEqual([groupMemberIDs count], 1, @"Should only be one item in group");
    XCTAssertEqual([groupMemberIDs anyObject], [assetIDs lastObject], @"Wrong asset in group");
}

- (void)testTagAssetWithNewTag {
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
        [moc obtainPermanentIDsForObjects:assets
                                    error:nil];
        assetIDs = [assets mapUsingBlock:^id _Nonnull(Asset * _Nonnull asset) { return asset.objectID; }];

        [moc save:nil];
    }];

    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __block BOOL innerSuccess = NO;
    __block NSError *innerError = nil;
    [library addAssets:[NSSet setWithObject:[assetIDs firstObject]]
                toTags:[NSSet setWithObject:@"Hello"]
              callback:^(BOOL success, NSError * _Nullable error) {
        innerSuccess = success;
        innerError = error;
        dispatch_semaphore_signal(sem);
    }];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    XCTAssertTrue(innerSuccess, @"Expected update to succeed");
    XCTAssertNil(innerError, @"Expected no error: %@", innerError);

    dispatch_semaphore_wait(delegate.updateSemaphore, DISPATCH_TIME_FOREVER);
    XCTAssertNotNil(delegate.changeNotificationData, @"Expected delegate to get change data");
    XCTAssertEqual([delegate.changeNotificationData count], 2, @"Expected both update and insert types");

    NSArray<NSManagedObjectID *> *inserts = delegate.changeNotificationData[NSInsertedObjectsKey];
    XCTAssertNotNil(inserts, @"Expected updates");
    XCTAssertEqual([inserts count], 1, @"Expected one tag inserted");

    NSArray<NSManagedObjectID *> *updates = delegate.changeNotificationData[NSUpdatedObjectsKey];
    XCTAssertNotNil(updates, @"Expected updates");
    XCTAssertEqual([updates count], 2, @"Expected both asset and tag to update");
    XCTAssertTrue([[NSSet setWithArray:updates] containsObject:[assetIDs firstObject]], @"Expected first asset in update");

    [NSManagedObjectContext mergeChangesFromRemoteContextSave:delegate.changeNotificationData
                                                 intoContexts:@[moc]];

    __block NSUInteger tagCounts = 0;
    __block NSString *tagName = nil;
    __block NSSet<NSManagedObjectID *> *tagMembershipIDs = nil;
    [moc performBlockAndWait:^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Tag"];
        NSArray<Tag *> *tags = [moc executeFetchRequest:fetch error:nil];
        tagCounts = [tags count];
        if (1 == tagCounts) {
            Tag *tag = [tags firstObject];
            tagName = tag.name;
            tagMembershipIDs = [tag.tags mapUsingBlock:^id _Nonnull(Asset * _Nonnull asset) {
                return asset.objectID;
            }];
        }
    }];
    XCTAssertEqual(tagCounts, 1, @"Expected one tag, got %lu", tagCounts);
    XCTAssertEqual([tagName compare:@"Hello"], NSOrderedSame, @"Tag name wasn't 'Hello': %@", tagName);
    XCTAssert([tagMembershipIDs isEqualTo:[NSSet setWithObject:[assetIDs firstObject]]], @"Wrong assets in tag");
}

- (void)testTagAssetWithExistingTag {
    NSManagedObjectContext *moc = [TestModelHelpers managedObjectContextForTests];
    LibraryWriteCoordinator *library = [[LibraryWriteCoordinator alloc] initWithPersistentStore:moc.persistentStoreCoordinator
                                                                          delegateCallbackQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    DelegateRecorder *delegate = [[DelegateRecorder alloc] init];
    delegate.updateSemaphore = dispatch_semaphore_create(0);
    library.delegate = delegate;

    __block NSArray<NSManagedObjectID *> *assetIDs = nil;
    __block NSManagedObjectID *tagID = nil;
    [moc performBlockAndWait:^{
        NSArray<Asset *> *assets = [TestModelHelpers generateAssets:2
                                                          inContext:moc];
        [moc obtainPermanentIDsForObjects:assets
                                    error:nil];
        assetIDs = [assets mapUsingBlock:^id _Nonnull(Asset * _Nonnull asset) { return asset.objectID; }];

        NSArray<Tag *> *tags = [TestModelHelpers generateTags:[NSSet setWithObject:@"Hello"]
                                                    inContext:moc];
        [moc obtainPermanentIDsForObjects:tags
                                    error:nil];
        tagID = [[tags firstObject] objectID];

        [moc save:nil];
    }];

    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __block BOOL innerSuccess = NO;
    __block NSError *innerError = nil;
    [library addAssets:[NSSet setWithObject:[assetIDs firstObject]]
                toTags:[NSSet setWithObject:@"HELLO"]
              callback:^(BOOL success, NSError * _Nullable error) {
        innerSuccess = success;
        innerError = error;
        dispatch_semaphore_signal(sem);
    }];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    XCTAssertTrue(innerSuccess, @"Expected update to succeed");
    XCTAssertNil(innerError, @"Expected no error: %@", innerError);

    dispatch_semaphore_wait(delegate.updateSemaphore, DISPATCH_TIME_FOREVER);
    XCTAssertNotNil(delegate.changeNotificationData, @"Expected delegate to get change data");
    XCTAssertEqual([delegate.changeNotificationData count], 1, @"Expected just update type");

    NSArray<NSManagedObjectID *> *updates = delegate.changeNotificationData[NSUpdatedObjectsKey];
    XCTAssertNotNil(updates, @"Expected updates");
    XCTAssertEqual([updates count], 2, @"Expected both asset and tag to update");
    XCTAssertTrue([[NSSet setWithArray:updates] containsObject:[assetIDs firstObject]], @"Expected first asset in update");
    XCTAssertTrue([[NSSet setWithArray:updates] containsObject:tagID], @"Expected tag in updates");

    [NSManagedObjectContext mergeChangesFromRemoteContextSave:delegate.changeNotificationData
                                                 intoContexts:@[moc]];
    
    __block NSSet<NSManagedObjectID *> *tagMemberIDs = nil;
    [moc performBlockAndWait:^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Tag"];
        NSArray<Tag *> *tags = [moc executeFetchRequest:fetch error:nil];
        tagMemberIDs = [[tags firstObject].tags mapUsingBlock:^id _Nonnull(Asset * _Nonnull asset) {
            return asset.objectID;
        }];
    }];
    XCTAssertEqual([tagMemberIDs count], 1, @"Should only be one item in tag");
    XCTAssertEqual([tagMemberIDs anyObject], [assetIDs firstObject], @"Wrong asset in tag");
}

@end
