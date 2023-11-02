//
//  NSArray+Functional.h
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 12/10/2023.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSArray<__covariant ObjectType> (Functional)

- (NSArray *)mapUsingBlock:(id (^)(ObjectType object))block;
- (NSArray *)compactMapUsingBlock:(id (^)(ObjectType object))block;

@end

NS_ASSUME_NONNULL_END
