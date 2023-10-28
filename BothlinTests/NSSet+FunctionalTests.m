//
//  NSSet+FunctionalTests.m
//  BothlinTests
//
//  Created by Michael Dales on 28/10/2023.
//

#import <XCTest/XCTest.h>
#import "NSSet+Functional.h"

@interface NSSet_FunctionalTests : XCTestCase

@end

@implementation NSSet_FunctionalTests

- (void)testMapEmpty {
    NSSet<NSString *> *data = [NSSet set];
    NSSet<NSNumber *> *result = [data mapUsingBlock:^id _Nonnull(NSString * _Nonnull object) {
        return @([object length]);
    }];
    XCTAssertTrue([result isEqualToSet:[NSSet set]], @"Expected empty array as result");
}

- (void)testMapSimple {
    NSSet<NSString *> *data = [NSSet setWithArray:@[@"one", @"two", @"three"]];
    NSSet<NSNumber *> *result = [data mapUsingBlock:^id _Nonnull(NSString * _Nonnull object) {
        return @([object length]);
    }];
    NSSet<NSNumber *> *expected = [NSSet setWithArray:@[@(3), @(3), @(5)]];
    XCTAssertTrue([result isEqualToSet:expected], @"Expected results incorrect");
}

- (void)testCompactMapEmpty {
    NSSet<NSString *> *data = [NSSet set];
    NSSet<NSNumber *> *result = [data compactMapUsingBlock:^id _Nonnull(NSString * _Nonnull object) {
        return @([object length]);
    }];
    XCTAssertTrue([result isEqualToSet:[NSSet set]], @"Expected empty array as result");
}

- (void)testCompactMapSimple {
    NSSet<NSString *> *data = [NSSet setWithArray:@[@"one", @"two", @"three"]];
    NSSet<NSNumber *> *result = [data compactMapUsingBlock:^id _Nonnull(NSString * _Nonnull object) {
        return @([object length]);
    }];
    NSSet<NSNumber *> *expected = [NSSet setWithArray:@[@(3), @(3), @(5)]];
    XCTAssertTrue([result isEqualToSet:expected], @"Expected results incorrect");
}

- (void)testCompactMapSomeMissing {
    NSSet<NSString *> *data = [NSSet setWithArray:@[@"one", @"two", @"three"]];
    NSSet<NSNumber *> *result = [data compactMapUsingBlock:^id _Nonnull(NSString * _Nonnull object) {
        if ([object length] > 4) {
            return @([object length]);
        }
        return nil;
    }];
    NSSet<NSNumber *> *expected = [NSSet setWithArray:@[@(5)]];
    XCTAssertTrue([result isEqualToSet:expected], @"Expected results incorrect");
}

@end
