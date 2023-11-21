//
//  NSManagedObjectContext+HelpersTexts.m
//  BothlinTests
//
//  Created by Michael Dales on 21/11/2023.
//

#import <XCTest/XCTest.h>

#import "NSManagedObjectContext+helpers.h"
#import "TestModelHelpers.h"
#import "Group+CoreDataClass.h"
#import "NSSet+Functional.h"

@interface NSManagedObjectContext_HelpersTexts : XCTestCase

@end

@implementation NSManagedObjectContext_HelpersTexts

- (void)testEmptySet {
    NSManagedObjectContext *moc = [TestModelHelpers  managedObjectContextForTests];
    NSError *error = nil;
    
    NSSet<Group *> *results = [moc existingObjectsWithIDs:[NSSet set]
                                                    error:&error];
    
    XCTAssertNil(error, @"Expected no error, got %@", error);
    XCTAssertNotNil(results, @"Expected results, got nil");
    XCTAssertEqual([results count], 0, @"Expected an empty result, got %ld items", [results count]);
}

- (void)testNonEmptySet {
    NSManagedObjectContext *moc = [TestModelHelpers  managedObjectContextForTests];
    NSError *error = nil;
    NSSet<Group *> *groups = [NSSet setWithArray:[TestModelHelpers generateGroups:5
                                                                        inContext:moc]];
    NSSet<NSManagedObjectID *> *groupIDs = [groups mapUsingBlock:^id _Nonnull(Group * _Nonnull group) { return group.objectID; }];

    NSSet<Group *> *results = [moc existingObjectsWithIDs:groupIDs
                                                    error:&error];
    
    XCTAssertNil(error, @"Expected no error, got %@", error);
    XCTAssertNotNil(results, @"Expected results, got nil");
    XCTAssertEqual([results count], [groupIDs count], @"Expected non empty result, got %ld items", [results count]);
}

- (void)testBadObjectID {
    NSManagedObjectContext *moc = [TestModelHelpers  managedObjectContextForTests];
    NSError *error = nil;
    NSSet<Group *> *groups = [NSSet setWithArray:[TestModelHelpers generateGroups:1
                                                                        inContext:moc]];
    NSSet<NSManagedObjectID *> *groupIDs = [groups mapUsingBlock:^id _Nonnull(Group * _Nonnull group) { return group.objectID; }];

    // This seems to be the easiest way to create an invalid object ID - you can't
    // instantiate NSManagedObjectID yourself, as you get an exception within Core Data
    [moc deleteObject:[groups anyObject]];
    [moc save:nil];

    NSSet<Group *> *results = [moc existingObjectsWithIDs:groupIDs
                                                    error:&error];

    XCTAssertNotNil(error, @"Expected error, got nil");
    XCTAssertNil(results, @"Expected results, got %@", results);
}


@end
