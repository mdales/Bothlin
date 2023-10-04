//
//  NSURL+SecureAccess.m
//  Bothlin
//
//  Created by Michael Dales on 30/09/2023.
//

#import "NSURL+SecureAccess.h"

@implementation NSURL (SecureAccess)


- (void)secureAccessWithBlock:(void (^)(NSURL *url, BOOL canAccess))block {
    if (nil == block) {
        return;
    }
    BOOL canAccess = [self startAccessingSecurityScopedResource];
    block(self, canAccess);
    if (NO != canAccess) {
        [self stopAccessingSecurityScopedResource];
    }
}

@end
