//
//  LibraryViewModelTests.m
//  BothlinTests
//
//  Created by Michael Dales on 04/11/2023.
//

#import <XCTest/XCTest.h>

#import "LibraryViewModel.h"
#import "LibraryWriteCoordinator.h"

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


@end
