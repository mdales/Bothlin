//
//  NSSet+Functional.m
//  Bothlin
//
//  Created by Michael Dales on 28/10/2023.
//

#import "NSSet+Functional.h"

@implementation NSSet (Functional)

- (NSSet *)mapUsingBlock:(id  _Nonnull (^)(id _Nonnull))block {
    NSParameterAssert(nil != block);

    NSMutableSet *result = [NSMutableSet setWithCapacity:[self count]];
    [self enumerateObjectsUsingBlock:^(id  _Nonnull obj, __unused BOOL * _Nonnull stop) {
        [result addObject:block(obj)];
    }];
    return [NSSet setWithSet:result];
}

- (NSSet *)compactMapUsingBlock:(id _Nullable (^)(id object))block {
    NSParameterAssert(nil != block);

    NSMutableSet *result = [NSMutableSet setWithCapacity:[self count]];
    [self enumerateObjectsUsingBlock:^(id  _Nonnull obj, __unused BOOL * _Nonnull stop) {
        id val = block(obj);
        if (nil != val) {
            [result addObject:val];
        }
    }];
    return [NSSet setWithSet:result];
}

@end
