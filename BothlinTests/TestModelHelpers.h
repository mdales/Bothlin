//
//  TestModelHelpers.h
//  BothlinTests
//
//  Created by Michael Dales on 09/11/2023.
//

#import <Cocoa/Cocoa.h>

@class Asset;
@class Group;
@class Tag;

NS_ASSUME_NONNULL_BEGIN

@interface TestModelHelpers : NSObject

+ (NSManagedObjectContext *)managedObjectContextForTests;

+ (NSArray<Asset *> *)generateAssets:(NSUInteger)assetCount
                           inContext:(NSManagedObjectContext *)moc;

+ (NSArray<Group *> *)generateGroups:(NSUInteger)groupCount
                           inContext:(NSManagedObjectContext *)moc;

+ (NSArray<Tag *> *)generateTags:(NSSet<NSString *> *)tagNames
                       inContext:(NSManagedObjectContext *)moc;

@end

NS_ASSUME_NONNULL_END
