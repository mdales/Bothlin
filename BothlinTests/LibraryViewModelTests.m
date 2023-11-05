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

@interface LibraryViewModelTests : XCTestCase

@end

@implementation LibraryViewModelTests

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

- (void)testNoDataAfterInit {
    NSManagedObjectContext *moc = [LibraryViewModelTests managedObjectContextForTests];
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
    NSManagedObjectContext *moc = [LibraryViewModelTests managedObjectContextForTests];
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
    NSManagedObjectContext *moc = [LibraryViewModelTests managedObjectContextForTests];
    LibraryViewModel *viewModel = [[LibraryViewModel alloc] initWithViewContext:moc
                                                               trashDisplayName:@"Trash"];
    XCTAssertNotNil(viewModel.selectedSidebarItem, @"No default selected sidebar item");

    NSUInteger count = 5;

    __block NSArray<NSManagedObjectID *> *assetIDs = nil;
    [moc performBlockAndWait:^{
        NSMutableArray<Asset *> *assets = [NSMutableArray arrayWithCapacity:count];
        for (NSUInteger index = 0; index < count; index++) {
            Asset *asset = [NSEntityDescription insertNewObjectForEntityForName:@"Asset"
                                                         inManagedObjectContext:moc];
            asset.name = [NSString stringWithFormat:@"test%lu.png", index];
            asset.path = [NSString stringWithFormat:@"/tmp/test%lu.png", index];
            asset.bookmark = nil;
            asset.added = [NSDate now];

            assets[index] = asset;
        }
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
    NSManagedObjectContext *moc = [LibraryViewModelTests managedObjectContextForTests];
    LibraryViewModel *viewModel = [[LibraryViewModel alloc] initWithViewContext:moc
                                                               trashDisplayName:@"Trash"];
    XCTAssertNotNil(viewModel.selectedSidebarItem, @"No default selected sidebar item");

    NSUInteger count = 5;

    __block NSArray<NSManagedObjectID *> *assetIDs = nil;
    [moc performBlockAndWait:^{
        NSMutableArray<Asset *> *assets = [NSMutableArray arrayWithCapacity:count];
        for (NSUInteger index = 0; index < count; index++) {
            Asset *asset = [NSEntityDescription insertNewObjectForEntityForName:@"Asset"
                                                         inManagedObjectContext:moc];
            asset.name = [NSString stringWithFormat:@"test%lu.png", index];
            asset.path = [NSString stringWithFormat:@"/tmp/test%lu.png", index];
            asset.bookmark = nil;
            asset.added = [NSDate now];

            // Mark only the first item as deleted
            if (0 == index) {
                asset.deletedAt = [NSDate now];
            }

            assets[index] = asset;
        }
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
    NSManagedObjectContext *moc = [LibraryViewModelTests managedObjectContextForTests];
    LibraryViewModel *viewModel = [[LibraryViewModel alloc] initWithViewContext:moc
                                                               trashDisplayName:@"Trash"];
    XCTAssertNotNil(viewModel.selectedSidebarItem, @"No default selected sidebar item");

    NSUInteger count = 5;

    __block NSArray<NSManagedObjectID *> *assetIDs = nil;
    [moc performBlockAndWait:^{
        NSMutableArray<Asset *> *assets = [NSMutableArray arrayWithCapacity:count];
        for (NSUInteger index = 0; index < count; index++) {
            Asset *asset = [NSEntityDescription insertNewObjectForEntityForName:@"Asset"
                                                         inManagedObjectContext:moc];
            asset.name = [NSString stringWithFormat:@"test%lu.png", index];
            asset.path = [NSString stringWithFormat:@"/tmp/test%lu.png", index];
            asset.bookmark = nil;
            asset.added = [NSDate now];

            assets[index] = asset;
        }
        assetIDs = [assets mapUsingBlock:^id _Nonnull(Asset * _Nonnull asset) { return asset.objectID; }];
    }];
    NSAssert(nil != assetIDs, @"Failed to generate asset ID list");

    LibraryWriteCoordinator *writeCoordinator = [[LibraryWriteCoordinator alloc] initWithPersistentStore:moc.persistentStoreCoordinator];
    [viewModel libraryWriteCoordinator:writeCoordinator
                             didUpdate:@{NSInsertedObjectsKey:assetIDs}];

    [viewModel setSearchText:@"test3"];

    XCTAssertNotNil(viewModel.assets, @"Should not be nil");
    XCTAssertEqual([viewModel.assets count], 1, @"Expected empty asset list");

    XCTAssertNotNil(viewModel.selectedAssetIndexPaths, @"Should not be nil");
    XCTAssertEqual([viewModel.selectedAssetIndexPaths count], 1, @"Expected no selection");

    XCTAssertNotNil(viewModel.selectedAssets, @"Should not be nil");
    XCTAssertEqual([viewModel.selectedAssets count], 1, @"Expected empty selected asset list");
}

- (void)testSimpleSearchNoMatchAssetTest {
    NSManagedObjectContext *moc = [LibraryViewModelTests managedObjectContextForTests];
    LibraryViewModel *viewModel = [[LibraryViewModel alloc] initWithViewContext:moc
                                                               trashDisplayName:@"Trash"];
    XCTAssertNotNil(viewModel.selectedSidebarItem, @"No default selected sidebar item");

    NSUInteger count = 5;

    __block NSArray<NSManagedObjectID *> *assetIDs = nil;
    [moc performBlockAndWait:^{
        NSMutableArray<Asset *> *assets = [NSMutableArray arrayWithCapacity:count];
        for (NSUInteger index = 0; index < count; index++) {
            Asset *asset = [NSEntityDescription insertNewObjectForEntityForName:@"Asset"
                                                         inManagedObjectContext:moc];
            asset.name = [NSString stringWithFormat:@"test%lu.png", index];
            asset.path = [NSString stringWithFormat:@"/tmp/test%lu.png", index];
            asset.bookmark = nil;
            asset.added = [NSDate now];

            assets[index] = asset;
        }
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
    NSManagedObjectContext *moc = [LibraryViewModelTests managedObjectContextForTests];
    LibraryViewModel *viewModel = [[LibraryViewModel alloc] initWithViewContext:moc
                                                               trashDisplayName:@"Trash"];
    XCTAssertNotNil(viewModel.selectedSidebarItem, @"No default selected sidebar item");

    NSUInteger count = 5;

    __block NSArray<NSManagedObjectID *> *groupIDs = nil;
    [moc performBlockAndWait:^{
        NSMutableArray<Group *> *groups = [NSMutableArray arrayWithCapacity:count];
        for (NSUInteger index = 0; index < count; index++) {
            Group *group = [NSEntityDescription insertNewObjectForEntityForName:@"Group"
                                                         inManagedObjectContext:moc];
            group.name = [NSString stringWithFormat:@"group %lu.png", index];

            groups[index] = group;
        }
        groupIDs = [groups mapUsingBlock:^id _Nonnull(Group * _Nonnull group) { return group.objectID; }];
    }];
    NSAssert(nil != groupIDs, @"Failed to generate grup ID list");

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


@end
