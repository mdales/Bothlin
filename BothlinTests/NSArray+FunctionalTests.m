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

- (void)testEmpty {
    NSArray<NSString *> *data = @[];
    NSArray<NSNumber *> *result = [data mapUsingBlock:^id _Nonnull(NSString * _Nonnull object) {
        return @([object length]);
    }];
    XCTAssertTrue([result isEqualToArray:@[]], @"Expected empty array as result");
}

- (void)testSimple {
    NSArray<NSString *> *data = @[@"one", @"two", @"three"];
    NSArray<NSNumber *> *result = [data mapUsingBlock:^id _Nonnull(NSString * _Nonnull object) {
        return @([object length]);
    }];
    NSArray<NSNumber *> *expected = @[@(3), @(3), @(5)];
    XCTAssertTrue([result isEqualToArray:expected], @"Expected results incorrect");
}

@end
