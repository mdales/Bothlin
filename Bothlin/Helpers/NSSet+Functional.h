//
//  NSSet+Functional.h
//  Bothlin
//
//  Created by Michael Dales on 28/10/2023.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSSet<__covariant ObjectType> (Functional)

- (NSSet *)mapUsingBlock:(id (^)(ObjectType object))block;

- (NSSet *)compactMapUsingBlock:(id _Nullable (^)(ObjectType object))block;

@end

NS_ASSUME_NONNULL_END
