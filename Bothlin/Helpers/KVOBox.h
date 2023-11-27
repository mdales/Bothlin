//
//  KVOBox.h
//  Bothlin
//
//  Created by Michael Dales on 18/10/2023.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KVOBox : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)observeObject:(id)object
                      keyPath:(NSString *)keyPath;
- (BOOL)startWithBlock:(void (^)(NSDictionary *))block
                 error:(NSError **)error;
- (BOOL)stop:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
