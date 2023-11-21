//
//  NSManagedObjectContext+helpers.m
//  Bothlin
//
//  Created by Michael Dales on 21/11/2023.
//

#import "NSManagedObjectContext+helpers.h"
#import "NSSet+Functional.h"

@implementation NSManagedObjectContext (helpers)

- (NSSet<__kindof NSManagedObject *> *)existingObjectsWithIDs:(NSSet<NSManagedObjectID *> *)objectIDs
                                                        error:(NSError * _Nullable *)error {
    NSParameterAssert(nil != objectIDs);
    __block NSError *innerError = nil;

    // We use compact map here just to make it easy to cope with errors, but we expect
    // the size of the result to be the same as the size of the inputs in the good case.
    NSSet<__kindof NSManagedObject *> *results = [objectIDs compactMapUsingBlock:^id _Nullable(NSManagedObjectID * _Nonnull objectID) {
        if (nil != innerError) {
            return nil;
        }
        return [self existingObjectWithID:objectID error:&innerError];
    }];
    if (nil != innerError) {
        if (nil != error) {
            *error = innerError;
        }
        return nil;
    }
    NSAssert([results count] == [objectIDs count], @"Expected results to be same length as objects");
    return results;
}

@end
