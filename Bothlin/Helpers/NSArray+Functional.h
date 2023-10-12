//
//  NSArray+Functional.h
//  Bothlin
//
//  Created by Michael Dales on 12/10/2023.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSArray<__covariant ObjectType> (Functional)

- (NSArray *)mapUsingBlock:(id (^)(ObjectType object))block;

@end

NS_ASSUME_NONNULL_END
