//
//  NSArray+Functional.m
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 12/10/2023.
//

#import "NSArray+Functional.h"

@implementation NSArray (Functional)

- (NSArray *)mapUsingBlock:(id (^)(id object))block {
    NSParameterAssert(nil != block);
    
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:[self count]];
    [self enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, __unused BOOL * _Nonnull stop) {
        result[idx] = block(obj);
    }];
    return [NSArray arrayWithArray:result];
}

- (NSArray *)compactMapUsingBlock:(id (^)(id object))block {
    NSParameterAssert(nil != block);

    NSMutableArray *result = [NSMutableArray array];
    [self enumerateObjectsUsingBlock:^(id  _Nonnull obj, __unused NSUInteger idx, __unused BOOL * _Nonnull stop) {
        id val = block(obj);
        if (nil != val) {
            [result addObject:val];
        }
    }];
    return [NSArray arrayWithArray:result];
}

@end
