//
//  LibraryViewModelTests.m
//  BothlinTests
//
//  Created by Michael Dales on 04/11/2023.
//

#import <XCTest/XCTest.h>

#import "LibraryViewModel.h"
#import "LibraryWriteCoordinator.h"
#import "NSArray+Functional.h"
#import "Asset+CoreDataClass.h"
#import "Group+CoreDataClass.h"
#import "SidebarItem.h"
#import "TestModelHelpers.h"

@interface LibraryViewModelTests : XCTestCase

@end

@implementation LibraryViewModelTests

- (void)testNoDataAfterInit {
    NSManagedObjectContext *moc = [TestModelHelpers  managedObjectContextForTests];
    LibraryViewModel *viewModel = [[LibraryViewModel alloc] initWithViewContext:moc
                                                               trashDisplayName:@"Trash"];
    XCTAssertNotNil(viewModel.assets, @"Should not be nil");
    XCTAssertEqual(viewModel.assets, @[], @"Expected empty asset list");

    XCTAssertNotNil(viewModel.selectedAssetIndexPaths, @"Should not be nil");
    XCTAssertEqual([viewModel.selectedAssetIndexPaths count], 0, @"Expected no selection");

    XCTAssertNotNil(viewModel.selectedAssets, @"Should not be nil");
    XCTAssertEqual([viewModel.selectedAssets count], 0, @"Expected empty selected asset list");

    XCTAssertNotNil(viewModel.groups, @"Should not be nil");
    XCTAssertEqual([viewModel.groups count], 0, @"Expected no groups");

    NSArray<SidebarItem *> *rootChildren = [viewModel.sidebarItems children];
    SidebarItem *groupSidebarItem = nil;
    for (SidebarItem *item in rootChildren) {
        if ([[item title] compare:@"Groups"] == NSOrderedSame) {
            groupSidebarItem = item;
            break;
        }
    }
    NSAssert(nil != groupSidebarItem, @"Failed to find sidebar item");
    XCTAssertEqual([[groupSidebarItem children] count], 0, @"Expected no groups in sidebar, got %lu", [[groupSidebarItem children] count]);
}

- (void)testNoDataAfterUpdate {
    NSManagedObjectContext *moc = [TestModelHelpers managedObjectContextForTests];
    LibraryViewModel *viewModel = [[LibraryViewModel alloc] initWithViewContext:moc
                                                               trashDisplayName:@"Trash"];

    LibraryWriteCoordinator *writeCoordinator = [[LibraryWriteCoordinator alloc] initWithPersistentStore:moc.persistentStoreCoordinator];
    [viewModel libraryWriteCoordinator:writeCoordinator
                             didUpdate:@{}];

    XCTAssertNotNil(viewModel.assets, @"Should not be nil");
    XCTAssertEqual(viewModel.assets, @[], @"Expected empty asset list");

    XCTAssertNotNil(viewModel.selectedAssetIndexPaths, @"Should not be nil");
    XCTAssertEqual([viewModel.selectedAssetIndexPaths count], 0, @"Expected no selection");

    XCTAssertNotNil(viewModel.selectedAssets, @"Should not be nil");
    XCTAssertEqual([viewModel.selectedAssets count], 0, @"Expected empty selected asset list");

    XCTAssertNotNil(viewModel.groups, @"Should not be nil");
    XCTAssertEqual([viewModel.groups count], 0, @"Expected no groups");
}

- (void)testSimpleAssetTest {
    NSManagedObjectContext *moc = [TestModelHelpers managedObjectContextForTests];
    LibraryViewModel *viewModel = [[LibraryViewModel alloc] initWithViewContext:moc
                                                               trashDisplayName:@"Trash"];
    XCTAssertNotNil(viewModel.selectedSidebarItem, @"No default selected sidebar item");

    NSUInteger count = 5;

    __block NSArray<NSManagedObjectID *> *assetIDs = nil;
    [moc performBlockAndWait:^{
        NSArray *assets = [TestModelHelpers generateAssets:count inContext:moc];
        assetIDs = [assets mapUsingBlock:^id _Nonnull(Asset * _Nonnull asset) { return asset.objectID; }];
    }];
    NSAssert(nil != assetIDs, @"Failed to generate asset ID list");

    LibraryWriteCoordinator *writeCoordinator = [[LibraryWriteCoordinator alloc] initWithPersistentStore:moc.persistentStoreCoordinator];
    [viewModel libraryWriteCoordinator:writeCoordinator
                             didUpdate:@{NSInsertedObjectsKey:assetIDs}];

    XCTAssertNotNil(viewModel.assets, @"Should not be nil");
    XCTAssertEqual([viewModel.assets count], 5, @"Expected empty asset list");

    XCTAssertNotNil(viewModel.selectedAssetIndexPaths, @"Should not be nil");
    XCTAssertEqual([viewModel.selectedAssetIndexPaths count], 1, @"Expected no selection");

    XCTAssertNotNil(viewModel.selectedAssets, @"Should not be nil");
    XCTAssertEqual([viewModel.selectedAssets count], 1, @"Expected empty selected asset list");
}

- (void)testSimpleSoftDeletedAssetTest {
    NSManagedObjectContext *moc = [TestModelHelpers managedObjectContextForTests];
    LibraryViewModel *viewModel = [[LibraryViewModel alloc] initWithViewContext:moc
                                                               trashDisplayName:@"Trash"];
    XCTAssertNotNil(viewModel.selectedSidebarItem, @"No default selected sidebar item");

    NSUInteger count = 5;

    __block NSArray<NSManagedObjectID *> *assetIDs = nil;
    [moc performBlockAndWait:^{
        NSArray *assets = [TestModelHelpers generateAssets:count inContext:moc];

        // Mark first item as deleted
        [[assets firstObject] setDeletedAt:[NSDate now]];

        assetIDs = [assets mapUsingBlock:^id _Nonnull(Asset * _Nonnull asset) { return asset.objectID; }];
    }];
    NSAssert(nil != assetIDs, @"Failed to generate asset ID list");

    LibraryWriteCoordinator *writeCoordinator = [[LibraryWriteCoordinator alloc] initWithPersistentStore:moc.persistentStoreCoordinator];
    [viewModel libraryWriteCoordinator:writeCoordinator
                             didUpdate:@{NSInsertedObjectsKey:assetIDs}];

    XCTAssertNotNil(viewModel.assets, @"Should not be nil");
    XCTAssertEqual([viewModel.assets count], 4, @"Expected empty asset list");

    XCTAssertNotNil(viewModel.selectedAssetIndexPaths, @"Should not be nil");
    XCTAssertEqual([viewModel.selectedAssetIndexPaths count], 1, @"Expected no selection");

    XCTAssertNotNil(viewModel.selectedAssets, @"Should not be nil");
    XCTAssertEqual([viewModel.selectedAssets count], 1, @"Expected empty selected asset list");

    // Change view to deleted
    SidebarItem *trashSidebarItem = [[viewModel.sidebarItems children] lastObject];
    NSAssert(nil != trashSidebarItem, @"Should have more than zero sidebar items");
    NSAssert([[trashSidebarItem title] compare:viewModel.trashDisplayName] == NSOrderedSame, @"Expected last sidebar item to be trash");
    [viewModel setSelectedSidebarItem:trashSidebarItem];

    XCTAssertNotNil(viewModel.assets, @"Should not be nil");
    XCTAssertEqual([viewModel.assets count], 1, @"Expected empty asset list");

    XCTAssertNotNil(viewModel.selectedAssetIndexPaths, @"Should not be nil");
    XCTAssertEqual([viewModel.selectedAssetIndexPaths count], 1, @"Expected no selection");

    XCTAssertNotNil(viewModel.selectedAssets, @"Should not be nil");
    XCTAssertEqual([viewModel.selectedAssets count], 1, @"Expected empty selected asset list");
}

- (void)testSimpleSearchAssetTest {
    NSManagedObjectContext *moc = [TestModelHelpers managedObjectContextForTests];
    LibraryViewModel *viewModel = [[LibraryViewModel alloc] initWithViewContext:moc
                                                               trashDisplayName:@"Trash"];
    XCTAssertNotNil(viewModel.selectedSidebarItem, @"No default selected sidebar item");

    NSUInteger count = 5;

    __block NSArray<NSManagedObjectID *> *assetIDs = nil;
    [moc performBlockAndWait:^{
        NSArray *assets = [TestModelHelpers generateAssets:count inContext:moc];
        assetIDs = [assets mapUsingBlock:^id _Nonnull(Asset * _Nonnull asset) { return asset.objectID; }];
    }];
    NSAssert(nil != assetIDs, @"Failed to generate asset ID list");

    LibraryWriteCoordinator *writeCoordinator = [[LibraryWriteCoordinator alloc] initWithPersistentStore:moc.persistentStoreCoordinator];
    [viewModel libraryWriteCoordinator:writeCoordinator
                             didUpdate:@{NSInsertedObjectsKey:assetIDs}];

    [viewModel setSearchText:@"test 3"];

    XCTAssertNotNil(viewModel.assets, @"Should not be nil");
    XCTAssertEqual([viewModel.assets count], 1, @"Expected empty asset list");

    XCTAssertNotNil(viewModel.selectedAssetIndexPaths, @"Should not be nil");
    XCTAssertEqual([viewModel.selectedAssetIndexPaths count], 1, @"Expected no selection");

    XCTAssertNotNil(viewModel.selectedAssets, @"Should not be nil");
    XCTAssertEqual([viewModel.selectedAssets count], 1, @"Expected empty selected asset list");
}

- (void)testSimpleSearchNoMatchAssetTest {
    NSManagedObjectContext *moc = [TestModelHelpers managedObjectContextForTests];
    LibraryViewModel *viewModel = [[LibraryViewModel alloc] initWithViewContext:moc
                                                               trashDisplayName:@"Trash"];
    XCTAssertNotNil(viewModel.selectedSidebarItem, @"No default selected sidebar item");

    NSUInteger count = 5;

    __block NSArray<NSManagedObjectID *> *assetIDs = nil;
    [moc performBlockAndWait:^{
        NSArray *assets = [TestModelHelpers generateAssets:count inContext:moc];
        assetIDs = [assets mapUsingBlock:^id _Nonnull(Asset * _Nonnull asset) { return asset.objectID; }];
    }];
    NSAssert(nil != assetIDs, @"Failed to generate asset ID list");

    LibraryWriteCoordinator *writeCoordinator = [[LibraryWriteCoordinator alloc] initWithPersistentStore:moc.persistentStoreCoordinator];
    [viewModel libraryWriteCoordinator:writeCoordinator
                             didUpdate:@{NSInsertedObjectsKey:assetIDs}];

    [viewModel setSearchText:@"foo"];

    XCTAssertNotNil(viewModel.assets, @"Should not be nil");
    XCTAssertEqual([viewModel.assets count], 0, @"Expected empty asset list");

    XCTAssertNotNil(viewModel.selectedAssetIndexPaths, @"Should not be nil");
    XCTAssertEqual([viewModel.selectedAssetIndexPaths count], 0, @"Expected no selection");

    XCTAssertNotNil(viewModel.selectedAssets, @"Should not be nil");
    XCTAssertEqual([viewModel.selectedAssets count], 0, @"Expected empty selected asset list");
}

- (void)testSimpleGroupTest {
    NSManagedObjectContext *moc = [TestModelHelpers managedObjectContextForTests];
    LibraryViewModel *viewModel = [[LibraryViewModel alloc] initWithViewContext:moc
                                                               trashDisplayName:@"Trash"];
    XCTAssertNotNil(viewModel.selectedSidebarItem, @"No default selected sidebar item");

    NSUInteger count = 5;

    __block NSArray<NSManagedObjectID *> *groupIDs = nil;
    [moc performBlockAndWait:^{
        NSArray<Group *> *groups = [TestModelHelpers generateGroups:count inContext:moc];
        groupIDs = [groups mapUsingBlock:^id _Nonnull(Group * _Nonnull group) { return group.objectID; }];
    }];
    NSAssert(nil != groupIDs, @"Failed to generate group ID list");

    LibraryWriteCoordinator *writeCoordinator = [[LibraryWriteCoordinator alloc] initWithPersistentStore:moc.persistentStoreCoordinator];
    [viewModel libraryWriteCoordinator:writeCoordinator
                             didUpdate:@{NSInsertedObjectsKey:groupIDs}];

    XCTAssertNotNil(viewModel.groups, @"Should not be nil");
    XCTAssertEqual([viewModel.groups count], 5, @"Expected empty asset list");

    NSArray<SidebarItem *> *rootChildren = [viewModel.sidebarItems children];
    SidebarItem *groupSidebarItem = nil;
    for (SidebarItem *item in rootChildren) {
        if ([[item title] compare:@"Groups"] == NSOrderedSame) {
            groupSidebarItem = item;
            break;
        }
    }
    NSAssert(nil != groupSidebarItem, @"Failed to find sidebar item");
    XCTAssertEqual([[groupSidebarItem children] count], count, @"Expected %lu groups in sidebar, got %lu", count, [[groupSidebarItem children] count]);
}

- (void)testAssetsInGroup {
    NSManagedObjectContext *moc = [TestModelHelpers managedObjectContextForTests];
    LibraryViewModel *viewModel = [[LibraryViewModel alloc] initWithViewContext:moc
                                                               trashDisplayName:@"Trash"];
    XCTAssertNotNil(viewModel.selectedSidebarItem, @"No default selected sidebar item");

    NSUInteger assetCount = 5;
    NSUInteger groupCount = 2;

    __block NSArray<NSManagedObjectID *> *assetIDs = nil;
    __block NSArray<NSManagedObjectID *> *groupIDs = nil;
    [moc performBlockAndWait:^{
        NSArray<Asset *> *assets = [TestModelHelpers generateAssets:assetCount inContext:moc];
        NSArray<Group *> *groups = [TestModelHelpers generateGroups:groupCount inContext:moc];

        // Add first asset to first group
        [[groups firstObject] addContains:[NSSet setWithObject:[assets firstObject]]];

        groupIDs = [groups mapUsingBlock:^id _Nonnull(Group * _Nonnull group) { return group.objectID; }];
        assetIDs = [assets mapUsingBlock:^id _Nonnull(Asset * _Nonnull asset) { return asset.objectID; }];
    }];
    NSAssert(nil != assetIDs, @"Failed to generate asset ID list");
    NSAssert(nil != groupIDs, @"Failed to generate group ID list");

    LibraryWriteCoordinator *writeCoordinator = [[LibraryWriteCoordinator alloc] initWithPersistentStore:moc.persistentStoreCoordinator];
    NSArray<NSManagedObjectID *> *allInsertedIDs = [groupIDs arrayByAddingObjectsFromArray:assetIDs];
    [viewModel libraryWriteCoordinator:writeCoordinator
                             didUpdate:@{NSInsertedObjectsKey:allInsertedIDs}];

    XCTAssertNotNil(viewModel.groups, @"Should not be nil");
    XCTAssertEqual([viewModel.groups count], groupCount, @"Expected group list");

    XCTAssertNotNil(viewModel.assets, @"Should not be nil");
    XCTAssertEqual([viewModel.assets count], assetCount, @"Expected asset list");

    NSArray<SidebarItem *> *rootChildren = [viewModel.sidebarItems children];
    SidebarItem *groupSidebarItem = nil;
    for (SidebarItem *item in rootChildren) {
        if ([[item title] compare:@"Groups"] == NSOrderedSame) {
            groupSidebarItem = item;
            break;
        }
    }
    NSAssert(nil != groupSidebarItem, @"Failed to find sidebar item");
    XCTAssertEqual([[groupSidebarItem children] count], groupCount, @"Expected a group in sidebar, got %lu", [[groupSidebarItem children] count]);

    [viewModel setSelectedSidebarItem:[[groupSidebarItem children] firstObject]];

    XCTAssertNotNil(viewModel.assets, @"Should not be nil");
    XCTAssertEqual([viewModel.assets count], 1, @"Expected asset list");

    [viewModel setSelectedSidebarItem:[[groupSidebarItem children] lastObject]];

    XCTAssertNotNil(viewModel.assets, @"Should not be nil");
    XCTAssertEqual([viewModel.assets count], 0, @"Expected no asset list");
}

- (void)testAssetsChangeSelectionRemains {
    NSManagedObjectContext *moc = [TestModelHelpers managedObjectContextForTests];
    LibraryViewModel *viewModel = [[LibraryViewModel alloc] initWithViewContext:moc
                                                               trashDisplayName:@"Trash"];
    XCTAssertNotNil(viewModel.selectedSidebarItem, @"No default selected sidebar item");

    NSUInteger assetCount = 10;
    NSUInteger groupCount = 2;

    __block NSArray<NSManagedObjectID *> *assetIDs = nil;
    __block NSArray<NSManagedObjectID *> *groupIDs = nil;
    [moc performBlockAndWait:^{
        NSArray<Asset *> *assets = [TestModelHelpers generateAssets:assetCount inContext:moc];
        NSArray<Group *> *groups = [TestModelHelpers generateGroups:groupCount inContext:moc];

        // Add every other asset to group
        for (NSUInteger index = 0; index < assetCount; index++) {
            Group *group = (index % 2) == 0 ? [groups firstObject] : [groups lastObject];
            [group addContains:[NSSet setWithObject:[assets objectAtIndex:index]]];
        }

        groupIDs = [groups mapUsingBlock:^id _Nonnull(Group * _Nonnull group) { return group.objectID; }];
        assetIDs = [assets mapUsingBlock:^id _Nonnull(Asset * _Nonnull asset) { return asset.objectID; }];
    }];
    NSAssert(nil != assetIDs, @"Failed to generate asset ID list");
    NSAssert(nil != groupIDs, @"Failed to generate group ID list");

    LibraryWriteCoordinator *writeCoordinator = [[LibraryWriteCoordinator alloc] initWithPersistentStore:moc.persistentStoreCoordinator];
    NSArray<NSManagedObjectID *> *allInsertedIDs = [groupIDs arrayByAddingObjectsFromArray:assetIDs];
    [viewModel libraryWriteCoordinator:writeCoordinator
                             didUpdate:@{NSInsertedObjectsKey:allInsertedIDs}];

    XCTAssertNotNil(viewModel.groups, @"Should not be nil");
    XCTAssertEqual([viewModel.groups count], groupCount, @"Expected group list");

    XCTAssertNotNil(viewModel.assets, @"Should not be nil");
    XCTAssertEqual([viewModel.assets count], assetCount, @"Expected asset list");

    XCTAssertEqual([viewModel.selectedAssets count], 1, @"Expected just one asset selected");
    NSManagedObjectID *selectedObjectID = [[viewModel selectedAssets] anyObject].objectID;

    NSArray<SidebarItem *> *rootChildren = [viewModel.sidebarItems children];
    SidebarItem *groupSidebarItem = nil;
    for (SidebarItem *item in rootChildren) {
        if ([[item title] compare:@"Groups"] == NSOrderedSame) {
            groupSidebarItem = item;
            break;
        }
    }
    NSAssert(nil != groupSidebarItem, @"Failed to find sidebar item");
    XCTAssertEqual([[groupSidebarItem children] count], groupCount, @"Expected a group in sidebar, got %lu", [[groupSidebarItem children] count]);

    // TODO: this test should really use a non default initial selection and ensure that's maintained

    SidebarItem *firstGroupSidebarItem = [[groupSidebarItem children] firstObject];
    XCTAssertEqual([firstGroupSidebarItem.title compare:@"group 0"], NSOrderedSame, @"Expected group 0, got %@", firstGroupSidebarItem.title);
    [viewModel setSelectedSidebarItem:firstGroupSidebarItem];

    XCTAssertNotNil(viewModel.assets, @"Should not be nil");
    XCTAssertEqual([viewModel.assets count], assetCount / 2, @"Expected asset list");
    XCTAssertEqual([viewModel.selectedAssets count], 1, @"Expected just one asset selected");
    NSManagedObjectID *firstGroupSelectedObjectID = [[viewModel selectedAssets] anyObject].objectID;
    XCTAssertNotEqual(selectedObjectID, firstGroupSelectedObjectID, @"Expected selection to be maintained");

    NSLog(@"Selected %@", viewModel.selectedAssets);

    SidebarItem *secondGroupSidebarItem = [[groupSidebarItem children] lastObject];
    XCTAssertEqual([secondGroupSidebarItem.title compare:@"group 1"], NSOrderedSame, @"Expected group 1, got %@", secondGroupSidebarItem.title);
    [viewModel setSelectedSidebarItem:secondGroupSidebarItem];

    XCTAssertNotNil(viewModel.assets, @"Should not be nil");
    XCTAssertEqual([viewModel.assets count], assetCount / 2, @"Expected no asset list");
    XCTAssertEqual([viewModel.selectedAssets count], 1, @"Expected just one asset selected");
    NSManagedObjectID *secondGroupSelectedObjectID = [[viewModel selectedAssets] anyObject].objectID;
    XCTAssertEqual(selectedObjectID, secondGroupSelectedObjectID, @"Expected selection to be changed");
}


@end
