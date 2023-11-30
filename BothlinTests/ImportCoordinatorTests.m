//
//  ImportCoordinatorTests.m
//  BothlinTests
//
//  Created by Michael Dales on 30/11/2023.
//

#import <XCTest/XCTest.h>

#import "ImportCoordinator.h"

@interface ImportCoordinatorTests : XCTestCase

@end

@implementation ImportCoordinatorTests

- (void)testFilterEmptyList {
    NSSet<NSURL *> *urls = [NSSet set];
    NSSet<NSURL *> *filteredURLs = [ImportCoordinator removeURLsForUnsupportedTypes:urls];

    XCTAssertNotNil(filteredURLs);
    XCTAssertEqual([filteredURLs count], 0);
}

- (void)testFilterCleanList {
    NSSet<NSURL *> *urls = [NSSet setWithArray:@[
        [NSURL fileURLWithPath:@"/tmp/test.png"],
        [NSURL fileURLWithPath:@"/tmp/test.txt"],
    ]];
    NSSet<NSURL *> *filteredURLs = [ImportCoordinator removeURLsForUnsupportedTypes:urls];

    XCTAssertNotNil(filteredURLs);
    XCTAssert([filteredURLs isEqualToSet:urls]);
}

- (void)testFilterMixedList {
    NSSet<NSURL *> *urls = [NSSet setWithArray:@[
        [NSURL fileURLWithPath:@"/tmp/test.png"],
        [NSURL fileURLWithPath:@"/tmp/test.txt"],
        [NSURL fileURLWithPath:@"/tmp/.DS_Store"],
        [NSURL fileURLWithPath:@"/tmp/desktop.ini"],
    ]];
    NSSet<NSURL *> *filteredURLs = [ImportCoordinator removeURLsForUnsupportedTypes:urls];

    XCTAssertNotNil(filteredURLs);
    XCTAssertEqual([filteredURLs count], [urls count] - 2);
}

@end
