//
//  NSURL+SecureAccess.h
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 30/09/2023.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSURL (SecureAccess)

- (void)secureAccessWithBlock:(void (^)(NSURL *url, BOOL canAccess))block;

@end

NS_ASSUME_NONNULL_END
