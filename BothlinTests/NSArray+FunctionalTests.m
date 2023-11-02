//
//  NSArray+FunctionalTests.m
//  BothlinTests - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 12/10/2023.
//

#import <XCTest/XCTest.h>
#import "NSArray+Functional.h"

@interface NSArray_FunctionalTests : XCTestCase

@end

@implementation NSArray_FunctionalTests

- (void)testMapEmpty {
    NSArray<NSString *> *data = @[];
    NSArray<NSNumber *> *result = [data mapUsingBlock:^id _Nonnull(NSString * _Nonnull object) {
        return @([object length]);
    }];
    XCTAssertTrue([result isEqualToArray:@[]], @"Expected empty array as result");
}

- (void)testMapSimple {
    NSArray<NSString *> *data = @[@"one", @"two", @"three"];
    NSArray<NSNumber *> *result = [data mapUsingBlock:^id _Nonnull(NSString * _Nonnull object) {
        return @([object length]);
    }];
    NSArray<NSNumber *> *expected = @[@(3), @(3), @(5)];
    XCTAssertTrue([result isEqualToArray:expected], @"Expected results incorrect");
}

- (void)testCompactMapEmpty {
    NSArray<NSString *> *data = @[];
    NSArray<NSNumber *> *result = [data compactMapUsingBlock:^id _Nonnull(NSString * _Nonnull object) {
        return @([object length]);
    }];
    XCTAssertTrue([result isEqualToArray:@[]], @"Expected empty array as result");
}

- (void)testCompactMapSimple {
    NSArray<NSString *> *data = @[@"one", @"two", @"three"];
    NSArray<NSNumber *> *result = [data compactMapUsingBlock:^id _Nonnull(NSString * _Nonnull object) {
        return @([object length]);
    }];
    NSArray<NSNumber *> *expected = @[@(3), @(3), @(5)];
    XCTAssertTrue([result isEqualToArray:expected], @"Expected results incorrect");
}

- (void)testCompactMapSomeMissing {
    NSArray<NSString *> *data = @[@"one", @"two", @"three"];
    NSArray<NSNumber *> *result = [data compactMapUsingBlock:^id _Nonnull(NSString * _Nonnull object) {
        if ([object length] > 4) {
            return @([object length]);
        }
        return nil;
    }];
    NSArray<NSNumber *> *expected = @[@(5)];
    XCTAssertTrue([result isEqualToArray:expected], @"Expected results incorrect");
}

@end
