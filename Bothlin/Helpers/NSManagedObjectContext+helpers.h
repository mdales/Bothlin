//
//  NSManagedObjectContext+helpers.h
//  Bothlin
//
//  Created by Michael Dales on 21/11/2023.
//

#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSManagedObjectContext (helpers)

- (NSSet<__kindof NSManagedObject *> *)existingObjectsWithIDs:(NSSet<NSManagedObjectID *> *)objectIDs
                                                        error:(NSError * _Nullable *)error;

@end

NS_ASSUME_NONNULL_END
