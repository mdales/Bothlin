//
//  TestModelHelpers.m
//  BothlinTests
//
//  Created by Michael Dales on 09/11/2023.
//

#import "TestModelHelpers.h"
#import "Asset+CoreDataClass.h"
#import "Group+CoreDataClass.h"

@implementation TestModelHelpers

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

+ (NSArray<Asset *> *)generateAssets:(NSUInteger)assetCount
                           inContext:(NSManagedObjectContext *)moc {
    NSMutableArray<Asset *> *assets = [NSMutableArray arrayWithCapacity:assetCount];
    for (NSUInteger index = 0; index < assetCount; index++) {
        Asset *asset = [NSEntityDescription insertNewObjectForEntityForName:@"Asset"
                                                     inManagedObjectContext:moc];
        asset.name = [NSString stringWithFormat:@"test %lu.png", index];
        asset.path = [NSString stringWithFormat:@"/tmp/test %lu.png", index];
        asset.bookmark = nil;
        asset.added = [NSDate now];
        asset.created = [NSDate dateWithTimeIntervalSinceNow:index];
        asset.bookmark = [NSData data];
        asset.type = @"public.png";

        assets[index] = asset;
    }
    return [NSArray arrayWithArray:assets];
}

+ (NSArray<Group *> *)generateGroups:(NSUInteger)groupCount
                           inContext:(NSManagedObjectContext *)moc {
    NSMutableArray<Group *> *groups = [NSMutableArray arrayWithCapacity:groupCount];
    for (NSUInteger index = 0; index < groupCount; index++) {
        Group *group = [NSEntityDescription insertNewObjectForEntityForName:@"Group"
                                                     inManagedObjectContext:moc];
        group.name = [NSString stringWithFormat:@"group %lu", index];

        groups[index] = group;
    }
    return [NSArray arrayWithArray:groups];
}

@end
