//
//  LibraryViewModel.h
//  Bothlin
//
//  Created by Michael Dales on 16/10/2023.
//

#import <Cocoa/Cocoa.h>

@class Item;
@class Group;

NS_ASSUME_NONNULL_BEGIN

@interface LibraryViewModel : NSObject

@property (nonatomic, strong, readonly) NSArray<Item *> *contents;
@property (nonatomic, strong, readwrite, nullable) Item *selected; // TODO: is this needed?
@property (nonatomic, strong, readonly) NSArray<Group *> *groups;

- (instancetype)initWithViewContext:(NSManagedObjectContext *)viewContext;

- (BOOL)reloadGroups:(NSError **)error;
- (BOOL)reloadItemsWithFetchRequest:(NSFetchRequest *)fetchRequest
                              error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
