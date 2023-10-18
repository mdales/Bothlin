//
//  LibraryViewModel.h
//  Bothlin
//
//  Created by Michael Dales on 16/10/2023.
//

#import <Cocoa/Cocoa.h>
#import "LibraryController.h"

@class Item;
@class Group;
@class SidebarItem;

NS_ASSUME_NONNULL_BEGIN

@interface LibraryViewModel : NSObject <LibraryControllerDelegate>

// TODO: Ideally these would a tuple to make KVO like updates easier
@property (nonatomic, strong, readonly) NSArray<Item *> *contents;
@property (nonatomic, strong, readwrite, nullable) Item *selected;

@property (nonatomic, strong, readonly) NSArray<Group *> *groups;

@property (nonatomic, strong, readonly) SidebarItem *sidebarItems;
@property (nonatomic, strong, readwrite) SidebarItem *selectedSidebarItem;

- (instancetype)initWithViewContext:(NSManagedObjectContext *)viewContext;

- (BOOL)reloadGroups:(NSError **)error;
- (BOOL)reloadItemsWithFetchRequest:(NSFetchRequest *)fetchRequest
                              error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
