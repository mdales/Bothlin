//
//  LibraryViewModel.m
//  Bothlin
//
//  Created by Michael Dales on 16/10/2023.
//

#import "LibraryViewModel.h"
#import "Asset+CoreDataClass.h"
#import "Group+CoreDataClass.h"
#import "Tag+CoreDataClass.h"
#import "NSArray+Functional.h"
#import "NSSet+Functional.h"
#import "Helpers.h"
#import "SidebarItem.h"

typedef NS_ENUM(NSUInteger, LibraryViewModelReloadCause) {
    LibraryViewModelReloadCauseUnknwn = 0,
    LibraryViewModelReloadCauseUpdate,
    LibraryViewModelReloadCauseViewChange,
    LibraryViewModelReloadCauseSearch,
};

NSArray<NSString *> * const testTags = @[
    @"Minecraft",
    @"QGIS",
    @"Other",
];

@interface LibraryViewModel ()

@property (nonatomic, strong, readonly, nonnull) dispatch_queue_t syncQ;
@property (nonatomic, strong, readonly, nonnull) NSManagedObjectContext *viewContext;

@property (nonatomic, strong, readwrite) NSArray<Asset *> *assets;
@property (nonatomic, strong, readwrite) NSArray<Group *> *groups;
@property (nonatomic, strong, readwrite) NSArray<Tag *> *tags;
@property (nonatomic, strong, readwrite) SidebarItem *sidebarItems;

@end


@implementation LibraryViewModel

@synthesize assets = _assets;
@synthesize selectedAssetIndexPaths = _selectedAssetIndexPaths;
@synthesize groups = _groups;
@synthesize selectedSidebarItem = _selectedSidebarItem;
@synthesize tags = _tags;

- (instancetype)initWithViewContext:(NSManagedObjectContext *)viewContext
                   trashDisplayName:(NSString *)trashDisplayName {
    NSParameterAssert(nil != viewContext);
    NSParameterAssert(nil != trashDisplayName);
    self = [super init];
    if (nil != self) {
        self->_syncQ = dispatch_queue_create("com.digitalflapjack.LibraryViewModel.syncQ", DISPATCH_QUEUE_SERIAL);
        self->_viewContext = viewContext;
        self->_assets = @[];
        self->_groups = @[];
        self->_tags = @[];
        self->_selectedAssetIndexPaths = [NSSet set];
        self->_sidebarItems = [LibraryViewModel buildMenuWithGroups:@[]
                                                   trashDisplayName:trashDisplayName];
        self->_selectedSidebarItem = [[self->_sidebarItems children] firstObject];
        self->_trashDisplayName = [NSString stringWithString:trashDisplayName];
        self->_searchText = @"";
    }
    return self;
}

#pragma mark - getters

- (NSArray<Asset *> *)assets {
    dispatch_assert_queue_not(self.syncQ);
    __block NSArray<Asset *> *val = nil;
    dispatch_sync(self.syncQ, ^{
        val = self->_assets;
    });
    return val;
}

- (NSSet<NSIndexPath *> *)selectedAssetIndexPaths {
    dispatch_assert_queue_not(self.syncQ);
    __block NSSet<NSIndexPath *> *val = nil;
    dispatch_sync(self.syncQ, ^{
        val = self->_selectedAssetIndexPaths;
    });
    NSAssert(nil != val, @"Index paths should not be nil");
    return val;
}

- (void)setSelectedAssetIndexPaths:(NSSet<NSIndexPath *> *)indexPaths {
    NSParameterAssert(nil != indexPaths);
    dispatch_assert_queue_not(self.syncQ);
    dispatch_sync(self.syncQ, ^{
        NSAssert(nil != self->_selectedAssetIndexPaths, @"Internal index paths is nil and shouldn't be");
        if ([self->_selectedAssetIndexPaths isEqualToSet:indexPaths]) {
            return;
        }
        self->_selectedAssetIndexPaths = [NSSet setWithSet:indexPaths];
    });
}

- (NSSet<Asset *> *)selectedAssets {
    dispatch_assert_queue_not(self.syncQ);
    __block NSSet<Asset *> *val = [NSSet set];
    dispatch_sync(self.syncQ, ^{
        NSAssert(nil != self->_selectedAssetIndexPaths, @"Index path should not be nil");
        // We need compactMap here as updates to the _asset set the the selection are not atomic in all cases, so
        // there are windows when they are briefly out of sync, causing us to not find currently selected
        // assets in the current view on assets.
        val = [self->_selectedAssetIndexPaths compactMapUsingBlock:^id _Nullable(NSIndexPath * _Nonnull object) {
            NSInteger index = [object item];
            if ((NSNotFound == index) || (0 > index) || ([self->_assets count] < index)) {
                return nil;
            }
            return [self->_assets objectAtIndex:(NSUInteger)index];
        }];
    });
    return val;
}

- (NSArray<Group *> *)groups {
    dispatch_assert_queue_not(self.syncQ);
    __block NSArray<Group *> *val;
    dispatch_sync(self.syncQ, ^{
        val = self->_groups;
    });
    return val;
}

- (SidebarItem *)selectedSidebarItem {
    dispatch_assert_queue_not(self.syncQ);
    __block SidebarItem *val = nil;
    dispatch_sync(self.syncQ, ^{
        val = self->_selectedSidebarItem;
    });
    return val;
}

- (void)setSelectedSidebarItem:(SidebarItem *)selectedSidebarItem {
    NSParameterAssert(nil != selectedSidebarItem);

    // We only allow selection of certain sidebar items, so
    // sanity check this first
    NSAssert(nil != selectedSidebarItem.fetchRequest, @"Allowed selection of a sidebar item with no fetch request.");

    dispatch_assert_queue_not(self.syncQ);
    dispatch_sync(self.syncQ, ^{
        if (self->_selectedSidebarItem == selectedSidebarItem) {
            return;
        }
        self->_selectedSidebarItem = selectedSidebarItem;

        NSError *error = nil;
        BOOL success = [self reloadAssetsWithCause:LibraryViewModelReloadCauseViewChange
                                             error:&error];
        if (nil != error) {
            NSAssert(NO == success, @"Got error but also success");
            [self.delegate libraryViewModel:self
                           hadErrorOnUpdate:error];
        }
        NSAssert(NO != success, @"Got no error and no success");
    });
}

- (NSArray<Tag *> *)tags {
    dispatch_assert_queue_not(self.syncQ);
    __block NSArray<Tag *> *val;
    dispatch_sync(self.syncQ, ^{
        val = self->_tags;
    });
    return val;
}

- (void)setSearchText:(NSString *)searchText {
    NSParameterAssert(nil != searchText);
    dispatch_assert_queue_not(self.syncQ);
    dispatch_sync(self.syncQ, ^{
        if ([self->_searchText compare:searchText] == NSOrderedSame) {
            return;
        }
        self->_searchText = searchText;
        NSError *error = nil;
        BOOL success = [self reloadAssetsWithCause:LibraryViewModelReloadCauseSearch
                                             error:&error];
        if (nil != error) {
            [self.delegate libraryViewModel:self
                           hadErrorOnUpdate:error];
        }
        NSAssert(NO != success, @"Got no error and no success");
    });
}

#pragma mark - ModelCoordinatorDelegate

- (void)modelCoordinator:(__unused id)modelCoordinator 
                      didUpdate:(NSDictionary<NSString *, NSArray<NSManagedObjectID *> *> *)changeNotificationData {
    dispatch_assert_queue(dispatch_get_main_queue());

    id<LibraryViewModelDelegate> delegate = self.delegate;

    [NSManagedObjectContext mergeChangesFromRemoteContextSave:changeNotificationData
                                                 intoContexts:@[self.viewContext]];

    // TODO: differentiate between inserts and updates to make the UI nicer
    // For now we at least check which class types have been updated to
    // minimise UI churn
    NSArray<NSManagedObjectID *> *inserted = changeNotificationData[NSInsertedObjectsKey];
    if (nil == inserted) {
        inserted = @[];
    }
    NSArray<NSManagedObjectID *> *updated = changeNotificationData[NSUpdatedObjectsKey];
    if (nil == updated) {
        updated = @[];
    }
    NSArray<NSManagedObjectID *> *deleted = changeNotificationData[NSDeletedObjectsKey];
    if (nil == deleted) {
        deleted = @[];
    }

    NSArray<NSManagedObjectID *> *all = [[inserted arrayByAddingObjectsFromArray:updated] arrayByAddingObjectsFromArray:deleted];

    NSArray<NSString *> *allClasses = [all mapUsingBlock:^id _Nonnull(NSManagedObjectID * _Nonnull object) {
        return [[object entity] name];
    }];
    NSSet<NSString *> *classes = [NSSet setWithArray:allClasses];

    if ([classes containsObject:NSStringFromClass([Group class])]) {
        NSError *error = nil;
        BOOL success = [self reloadGroups:&error];
        if (nil != error) {
            [delegate libraryViewModel:self
                      hadErrorOnUpdate:error];
        }
        NSAssert(NO != success, @"Got no error and no success");
    }

    if ([classes containsObject:NSStringFromClass([Tag class])]) {
        NSError *error = nil;
        BOOL success = [self reloadTags:&error];
        if (nil != error) {
            [delegate libraryViewModel:self
                      hadErrorOnUpdate:error];
        }
        NSAssert(NO != success, @"Got no error and no success");
    }

    if ([classes containsObject:NSStringFromClass([Asset class])]) {
        // TODO: This is all very crude, but let's get something working
        // before we end up down a perfect diffing rabbit hole.
        dispatch_sync(self.syncQ, ^{
            NSError *error = nil;
            BOOL success = [self reloadAssetsWithCause:LibraryViewModelReloadCauseUpdate
                                                 error:&error];
            if (nil != error) {
                NSAssert(NO == success, @"Got error and success on reloading assets");
                [self.delegate libraryViewModel:self
                               hadErrorOnUpdate:error];
            } else {
                NSAssert(NO != success, @"Got no error and no success reloading assets");
            }
        });
    }
}

#pragma mark - LibraryWriteCoordinatorDelegate

- (void)libraryWriteCoordinator:(__unused LibraryWriteCoordinator *)libraryWriteCoordinator
               thumbnailForItem:(__unused NSManagedObjectID *)objectID
      generationFailedWithError:(NSError *)error {
    [self.delegate libraryViewModel:self
                   hadErrorOnUpdate:error];
}

#pragma mark - Data management

- (BOOL)reloadGroups:(NSError **)error {
    dispatch_assert_queue_not(self.syncQ);
    dispatch_assert_queue(dispatch_get_main_queue());

    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"Group"];
    NSPredicate *filter = [NSPredicate predicateWithFormat:@"internal == NO"];
    [fetchRequest setPredicate:filter];
    NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"name"
                                                           ascending:YES];
    [fetchRequest setSortDescriptors:@[sort]];

    NSError *innerError = nil;
    NSArray<Group *> *result = [self.viewContext executeFetchRequest:fetchRequest
                                                               error:&innerError];
    if (nil != innerError) {
        NSAssert(nil == result, @"Got error and fetch results.");
        if (nil != error) {
            *error = innerError;
        }
        return NO;
    }
    NSAssert(nil != result, @"Got no error and no fetch results.");

    dispatch_sync(self.syncQ, ^{
        self.groups = result;
        self.sidebarItems = [LibraryViewModel buildMenuWithGroups:result
                                                 trashDisplayName:self.trashDisplayName];
    });

    return YES;
}

- (BOOL)reloadTags:(NSError **)error {
    dispatch_assert_queue_not(self.syncQ);
    dispatch_assert_queue(dispatch_get_main_queue());

    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"Tag"];
    NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"name"
                                                           ascending:YES];
    [fetchRequest setSortDescriptors:@[sort]];

    NSError *innerError = nil;
    NSArray<Tag *> *result = [self.viewContext executeFetchRequest:fetchRequest
                                                             error:&innerError];
    if (nil != innerError) {
        NSAssert(nil == result, @"Got error and fetch results.");
        if (nil != error) {
            *error = innerError;
        }
        return NO;
    }
    NSAssert(nil != result, @"Got no error and no fetch results.");

    dispatch_sync(self.syncQ, ^{
        self.tags = result;
    });

    return YES;
}

- (BOOL)reloadAssetsWithCause:(__unused LibraryViewModelReloadCause)reloadCause
                        error:(NSError **)error {
    // TODO: plumb in reloadCause to let us make a more sensible selection
    // when an item is deleted from the current view vs we changed views entirely
    dispatch_assert_queue(self.syncQ);
    dispatch_assert_queue(dispatch_get_main_queue());

    if (nil == self->_selectedSidebarItem) {
        if (nil != error) {
            *error = [NSError errorWithDomain:NSPOSIXErrorDomain
                                         code:EINVAL
                                     userInfo:nil];
        }
        return NO;
    }

    NSFetchRequest *request = [self->_selectedSidebarItem.fetchRequest copy];
    NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"created"
                                                           ascending:YES];
    if ([self->_searchText length] > 0) {
        NSPredicate *predicte = [request predicate];
        NSPredicate *searchNamePredicate = [NSPredicate predicateWithFormat:@"name CONTAINS[cd] %@", self->_searchText];
        NSPredicate *searchScannedTextPredicate = [NSPredicate predicateWithFormat:@"scannedText CONTAINS[cd] %@", self->_searchText];
        NSCompoundPredicate *searchPredicate = [[NSCompoundPredicate alloc] initWithType:NSOrPredicateType
                                                                           subpredicates:@[searchNamePredicate, searchScannedTextPredicate]];
        NSCompoundPredicate *combinedPredicate = [[NSCompoundPredicate alloc] initWithType:NSAndPredicateType
                                                                             subpredicates:@[predicte, searchPredicate]];
        [request setPredicate:combinedPredicate];
    }
    [request setSortDescriptors:@[sort]];

    NSError *innerError = nil;
    NSArray<Asset *> *result = [self.viewContext executeFetchRequest:request
                                                              error:&innerError];
    if (nil != innerError) {
        NSAssert(nil == result, @"Got error and fetch results.");
        if (nil != error) {
            *error = innerError;
        }
        return NO;
    }
    NSAssert(nil != result, @"Got no error and no fetch results.");

    // Are any of the old selected assets in the new data? If so, keep them selected?
    // If not default to just having the most recent by time
    // TODO: one day the assumption this is the last item will not be true
    NSSet<NSIndexPath *> *newSelectionIndexPaths = [result count] > 0 ?
        [NSSet setWithObject: [NSIndexPath indexPathForItem:((NSInteger)[result count] - 1) inSection:0]] :
        [NSSet set];
    if (([result count] > 0) && ([self->_assets count] > 0)) {
        NSSet<NSIndexPath *> *selected = [self->_selectedAssetIndexPaths compactMapUsingBlock:^id _Nullable(NSIndexPath * _Nonnull indexPath) {
            NSInteger idx = [indexPath item];
            if ((NSNotFound == idx) || (0 > idx) || ([self->_assets count] < idx)) {
                return nil;
            }
            Asset *selected = [self->_assets objectAtIndex:(NSUInteger)[indexPath item]];
            NSUInteger newIndex = [result indexOfObject:selected];
            if (NSNotFound == newIndex) {
                return nil;
            }
            return [NSIndexPath indexPathForItem:(NSInteger)newIndex inSection:0];
        }];
        if ([selected count] > 0) {
            newSelectionIndexPaths = selected;
        }
    }

    [self willChangeValueForKey:NSStringFromSelector(@selector(assets))];
    [self willChangeValueForKey:NSStringFromSelector(@selector(selectedAssetIndexPaths))];

    self->_assets = result;
    self->_selectedAssetIndexPaths = newSelectionIndexPaths;

    [self didChangeValueForKey:NSStringFromSelector(@selector(assets))];
    [self didChangeValueForKey:NSStringFromSelector(@selector(selectedAssetIndexPaths))];

    return YES;
}

+ (SidebarItem * _Nonnull)buildMenuWithGroups:(NSArray<Group *> * _Nonnull)groups
                             trashDisplayName:(NSString *)trashDisplayName {
    // TODO: Can we load this from JSON/plist?
    NSFetchRequest *everythingRequest = [NSFetchRequest fetchRequestWithEntityName:@"Asset"];
    [everythingRequest setPredicate:[NSPredicate predicateWithFormat: @"deletedAt == nil"]];
    SidebarItem *everything = [[SidebarItem alloc] initWithTitle:@"Everything"
                                                      symbolName:@"shippingbox"
                                                dragResponseType:SidebarItemDragResponseNone
                                                        children:nil
                                                    fetchRequest:everythingRequest
                                                   relatedObject:nil
                                                            uuid:[[NSUUID alloc] initWithUUIDString:@"f9d907a7-99f2-4112-8680-5160c656ee4d"]];

    NSFetchRequest *favouriteRequest = [NSFetchRequest fetchRequestWithEntityName:@"Asset"];
    [favouriteRequest setPredicate:[NSPredicate predicateWithFormat: @"favourite == YES"]];
    SidebarItem *favourites = [[SidebarItem alloc] initWithTitle:@"Favourites"
                                                      symbolName:@"heart"
                                                dragResponseType:SidebarItemDragResponseFavourite
                                                        children:nil
                                                    fetchRequest:favouriteRequest
                                                   relatedObject:nil
                                                            uuid:[[NSUUID alloc] initWithUUIDString:@"7e555562-353c-4365-b6fe-863950d9693f"]];

    SidebarItem *groupsItem = [[SidebarItem alloc] initWithTitle:@"Groups"
                                                      symbolName:@"folder"
                                                dragResponseType:SidebarItemDragResponseNone
                                                        children:[groups mapUsingBlock:^SidebarItem * _Nonnull(Group * _Nonnull group) {
        NSFetchRequest *groupRequest = [NSFetchRequest fetchRequestWithEntityName:@"Asset"];
        NSPredicate *groupPredicate = [NSPredicate predicateWithFormat: @"ANY groups == %@", group];
        NSPredicate *notDeletedPredicate = [NSPredicate predicateWithFormat: @"deletedAt == nil"];
        NSCompoundPredicate *combindedGroupPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[groupPredicate, notDeletedPredicate]];
        [groupRequest setPredicate:combindedGroupPredicate];
        return [[SidebarItem alloc] initWithTitle:group.name
                                       symbolName:nil
                                 dragResponseType:SidebarItemDragResponseGroup
                                         children:nil
                                     fetchRequest:groupRequest
                                    relatedObject:group.objectID
                                             uuid:[NSUUID UUID]];
    }]
                                                    fetchRequest:nil
                                                   relatedObject:nil
                                                            uuid:[[NSUUID alloc] initWithUUIDString:@"48e8126a-40c6-4076-ae36-154829ca77a7"]];

    SidebarItem *tags = [[SidebarItem alloc] initWithTitle:@"Popular Tags"
                                                symbolName:@"tag"
                                          dragResponseType:SidebarItemDragResponseNone
                                                  children:[testTags mapUsingBlock:^SidebarItem * _Nonnull(NSString * _Nonnull title) {
        return [[SidebarItem alloc] initWithTitle:title
                                       symbolName:nil
                                 dragResponseType:SidebarItemDragResponseNone
                                         children:nil
                                     fetchRequest:nil
                                    relatedObject:nil
                                             uuid:[NSUUID UUID]];
    }]
                                              fetchRequest:nil
                                             relatedObject:nil
                                                      uuid:[[NSUUID alloc] initWithUUIDString:@"d0cbc8b6-cf82-45b7-9c14-8fa54a997c92"]];



    NSFetchRequest *trashReequest = [NSFetchRequest fetchRequestWithEntityName:@"Asset"];
    [trashReequest setPredicate:[NSPredicate predicateWithFormat: @"deletedAt != nil"]];
    SidebarItem *trash = [[SidebarItem alloc] initWithTitle:trashDisplayName
                                                 symbolName:@"trash"
                                           dragResponseType:SidebarItemDragResponseTrash
                                                   children:nil
                                               fetchRequest:trashReequest
                                              relatedObject:nil
                                                       uuid:[[NSUUID alloc] initWithUUIDString:@"14b0db34-7698-41e5-ba25-dd4b0e5db1d1"]];

    SidebarItem *root = [[SidebarItem alloc] initWithTitle:@"toplevel"
                                                symbolName:nil
                                          dragResponseType:SidebarItemDragResponseNone
                                                  children:@[everything, favourites, groupsItem, tags, trash]
                                              fetchRequest:nil
                                             relatedObject:nil
                                                      uuid:[[NSUUID alloc] initWithUUIDString:@"2ff8f5bd-e8db-4a3e-bf5b-bf4e6d1471e2"]];

    return root;
}

@end
