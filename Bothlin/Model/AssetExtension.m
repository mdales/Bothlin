//
//  AssetExtension.m
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 28/09/2023.
//

#import "AssetExtension.h"
#import "AppDelegate.h"
#import "NSURL+SecureAccess.h"

@implementation Asset (Helpers)

- (NSURL*)decodeSecureURL:(NSError**)error {
    BOOL isStale = NO;
    NSError *innerError = nil;
    NSURL *decoded = [NSURL URLByResolvingBookmarkData:self.bookmark
                                               options:NSURLBookmarkResolutionWithSecurityScope
                                         relativeToURL:nil
                                   bookmarkDataIsStale:&isStale
                                                 error:&innerError];
    if (nil != innerError) {
        NSAssert(nil == decoded, @"Got error decoding secure URL and a result");
        if (nil != error) {
            *error = innerError;
        }
        return nil;
    }
    NSAssert(nil != decoded, @"Got no error and no result");
    if (NO != isStale) {
        if (nil != error) {
            *error = [NSError errorWithDomain:NSPOSIXErrorDomain
                                         code:ESTALE
                                     userInfo:@{
                @"ID": self.objectID,
                @"Path": decoded
            }];
        }
        return nil;
    }
    return decoded;
}

@end
