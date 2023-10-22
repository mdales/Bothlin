//
//  LibraryViewModel.h
//  Bothlin
//
//  Created by Michael Dales on 16/10/2023.
//

#import <Cocoa/Cocoa.h>
#import "LibraryController.h"

@class Asset;
@class Group;
@class SidebarItem;
@class LibraryViewModel;

NS_ASSUME_NONNULL_BEGIN

@protocol LibraryViewModelDelegate <NSObject>

- (void)libraryViewModel:(LibraryViewModel *)libraryViewModel
        hadErrorOnUpdate:(NSError *)error;

@end

@interface LibraryViewModel : NSObject <LibraryControllerDelegate>

@property (nonatomic, weak, readwrite) id<LibraryViewModelDelegate> delegate;

// TODO: Ideally these would a tuple to make KVO like updates easier
@property (nonatomic, strong, readonly) NSArray<Asset *> *assets;
@property (nonatomic, strong, readwrite) NSIndexPath *selectedAssetIndexPath;
@property (nonatomic, strong, readonly, nullable) Asset *selectedAsset;

@property (nonatomic, strong, readonly) NSArray<Group *> *groups;

@property (nonatomic, strong, readonly) SidebarItem *sidebarItems;
@property (nonatomic, strong, readwrite) SidebarItem *selectedSidebarItem;

- (instancetype)initWithViewContext:(NSManagedObjectContext *)viewContext;

- (BOOL)reloadGroups:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
