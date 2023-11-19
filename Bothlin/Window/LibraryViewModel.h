//
//  LibraryViewModel.h
//  Bothlin
//
//  Created by Michael Dales on 16/10/2023.
//

#import <Cocoa/Cocoa.h>
#import "LibraryWriteCoordinator.h"

@class Asset;
@class Group;
@class Tag;

@class SidebarItem;
@class LibraryViewModel;

NS_ASSUME_NONNULL_BEGIN

@protocol LibraryViewModelDelegate <NSObject>

- (void)libraryViewModel:(LibraryViewModel *)libraryViewModel
        hadErrorOnUpdate:(NSError *)error;

@end

@interface LibraryViewModel : NSObject <LibraryWriteCoordinatorDelegate>

@property (nonatomic, weak, readwrite) id<LibraryViewModelDelegate> delegate;

@property (nonatomic, strong, readonly, nonnull) NSString *trashDisplayName;

// TODO: Ideally these would a tuple to make KVO like updates easier
@property (nonatomic, strong, readonly) NSArray<Asset *> *assets;
@property (nonatomic, strong, readwrite) NSSet<NSIndexPath *> *selectedAssetIndexPaths;
@property (nonatomic, strong, readonly) NSSet<Asset *> *selectedAssets;

@property (nonatomic, strong, readonly) NSArray<Group *> *groups;

@property (nonatomic, strong, readonly) SidebarItem *sidebarItems;
@property (nonatomic, strong, readwrite) SidebarItem *selectedSidebarItem;

@property (nonatomic, strong, readwrite) NSString *searchText;

@property (nonatomic, strong, readonly) NSArray<Tag *> *tags;

- (instancetype)initWithViewContext:(NSManagedObjectContext *)viewContext
                   trashDisplayName:(NSString *)trashDisplayName;

- (BOOL)reloadGroups:(NSError **)error;
- (BOOL)reloadTags:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
