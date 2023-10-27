//
//  LibraryViewModel.m
//  Bothlin
//
//  Created by Michael Dales on 16/10/2023.
//

#import "LibraryViewModel.h"
#import "Asset+CoreDataClass.h"
#import "Group+CoreDataClass.h"
#import "NSArray+Functional.h"
#import "Helpers.h"
#import "SidebarItem.h"

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
@property (nonatomic, strong, readwrite) SidebarItem *sidebarItems;

@end


@implementation LibraryViewModel

@synthesize assets = _assets;
@synthesize selectedAssetIndexPath = _selectedAssetIndexPath;
@synthesize groups = _groups;
@synthesize selectedSidebarItem = _selectedSidebarItem;

- (instancetype)initWithViewContext:(NSManagedObjectContext *)viewContext {
    self = [super init];
    if (nil != self) {
        self->_syncQ = dispatch_queue_create("com.digitalflapjack.LibraryViewModel.syncQ", DISPATCH_QUEUE_SERIAL);
        self->_viewContext = viewContext;
        self->_assets = @[];
        self->_selectedAssetIndexPath = [[NSIndexPath alloc] init];
        self->_sidebarItems = [LibraryViewModel buildMenuWithGroups:@[]];
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

- (NSIndexPath *)selectedAssetIndexPath {
    dispatch_assert_queue_not(self.syncQ);
    __block NSIndexPath *val = nil;
    dispatch_sync(self.syncQ, ^{
        val = self->_selectedAssetIndexPath;
    });
    NSAssert(nil != val, @"Index path should not be nil");
    return val;
}

- (void)setSelectedAssetIndexPath:(NSIndexPath *)indexPath {
    NSParameterAssert(nil != indexPath);
    dispatch_assert_queue_not(self.syncQ);
    dispatch_sync(self.syncQ, ^{
        if ((nil == indexPath) && (nil == self->_selectedAssetIndexPath)) {
            return;
        }
        // you still need to do a nil check here as NSOrderedSame is zero, so if selectedAssetIndex is
        // nil you get a false positive
        if ((nil != self->_selectedAssetIndexPath) && ([self->_selectedAssetIndexPath compare:indexPath] == NSOrderedSame)) {
            return;
        }
        self->_selectedAssetIndexPath = indexPath;
    });
}

- (Asset *)selectedAsset {
    dispatch_assert_queue_not(self.syncQ);
    __block Asset *val = nil;
    dispatch_sync(self.syncQ, ^{
        NSAssert(nil != self->_selectedAssetIndexPath, @"Index path should not be nil");
        NSInteger index = [self->_selectedAssetIndexPath item];
        if (NSNotFound == index) {
            return;
        }
        val = [self->_assets objectAtIndex:(NSUInteger)index];
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
        BOOL success = [self reloadAssets:&error];
        if (nil != error) {
            NSAssert(NO == success, @"Got error but also success");
            [self.delegate libraryViewModel:self
                           hadErrorOnUpdate:error];
        }
        NSAssert(NO != success, @"Got no error and no success");
    });
}

#pragma mark - LibraryWriteCoordinatorDelegate

- (void)libraryWriteCoordinator:(__unused LibraryWriteCoordinator *)libraryWriteCoordinator 
                      didUpdate:(NSDictionary *)changeNotificationData {
    dispatch_assert_queue(dispatch_get_main_queue());

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
    NSArray<NSManagedObjectID *> *all = [inserted arrayByAddingObjectsFromArray:updated];

    NSArray<NSString *> *allClasses = [all mapUsingBlock:^id _Nonnull(NSManagedObjectID * _Nonnull object) {
        return [[object entity] name];
    }];
    NSSet<NSString *> *classes = [NSSet setWithArray:allClasses];

    if ([classes containsObject:NSStringFromClass([Group class])]) {
        NSError *error = nil;
        BOOL success = [self reloadGroups:&error];
        if (nil != error) {
            [self.delegate libraryViewModel:self
                           hadErrorOnUpdate:error];
        }
        NSAssert(NO != success, @"Got no error and no success");
    }

    if ([classes containsObject:NSStringFromClass([Asset class])]) {
        // TODO: This is all very crude, but let's get something working
        // before we end up down a perfect diffing rabbit hole.
        dispatch_sync(self.syncQ, ^{
            NSError *error = nil;
            BOOL success = [self reloadAssets:&error];
            if (nil != error) {
                [self.delegate libraryViewModel:self
                               hadErrorOnUpdate:error];
            }
            NSAssert(NO != success, @"Got no error and no success");
        });
    }
}

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
        self.sidebarItems = [LibraryViewModel buildMenuWithGroups:result];
    });

    return YES;
}

- (BOOL)reloadAssets:(NSError **)error {
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

    // Is the old selected asset in the new data? If so, keep it selected
    NSIndexPath *newSelectionIndexPath = [result count] > 0 ? [NSIndexPath indexPathForItem:((NSInteger)[result count] - 1) inSection:0] : [[NSIndexPath alloc] init];
    if (([result count] > 0) && ([self->_assets count] > 0)) {
        Asset *selected = [self->_assets objectAtIndex:(NSUInteger)[self->_selectedAssetIndexPath item]];
        if (nil != selected) {
            NSUInteger newIndex = [result indexOfObject:selected];
            if (NSNotFound != newIndex) {
                newSelectionIndexPath = [NSIndexPath indexPathForItem:(NSInteger)newIndex inSection:0];
            }
        }
    }

    [self willChangeValueForKey:@"assets"];
    [self willChangeValueForKey:@"selectedAssetIndexPath"];

    self->_assets = result;
    self->_selectedAssetIndexPath = newSelectionIndexPath;

    [self didChangeValueForKey:@"assets"];
    [self didChangeValueForKey:@"selectedAssetIndexPath"];

    return YES;
}

+ (SidebarItem * _Nonnull)buildMenuWithGroups:(NSArray<Group *> * _Nonnull)groups {
    NSFetchRequest *everythingRequest = [NSFetchRequest fetchRequestWithEntityName:@"Asset"];
    [everythingRequest setPredicate:[NSPredicate predicateWithFormat: @"deletedAt == nil"]];
    SidebarItem *everything = [[SidebarItem alloc] initWithTitle:@"Everything"
                                                      symbolName:@"shippingbox"
                                                dragResponseType:SidebarItemDragResponseNone
                                                        children:nil
                                                    fetchRequest:everythingRequest
                                                   relatedObject:nil];

    NSFetchRequest *favouriteRequest = [NSFetchRequest fetchRequestWithEntityName:@"Asset"];
    [favouriteRequest setPredicate:[NSPredicate predicateWithFormat: @"favourite == YES"]];
    SidebarItem *favourites = [[SidebarItem alloc] initWithTitle:@"Favourites"
                                                      symbolName:@"heart"
                                                dragResponseType:SidebarItemDragResponseFavourite
                                                        children:nil
                                                    fetchRequest:favouriteRequest
                                                   relatedObject:nil];

    SidebarItem *groupsItem = [[SidebarItem alloc] initWithTitle:@"Groups"
                                                      symbolName:@"folder"
                                                dragResponseType:SidebarItemDragResponseNone
                                                        children:[groups mapUsingBlock:^SidebarItem * _Nonnull(Group * _Nonnull group) {
        NSFetchRequest *groupRequest = [NSFetchRequest fetchRequestWithEntityName:@"Asset"];
        [groupRequest setPredicate:[NSPredicate predicateWithFormat: @"ANY groups == %@", group]];
        return [[SidebarItem alloc] initWithTitle:group.name
                                       symbolName:nil
                                 dragResponseType:SidebarItemDragResponseGroup
                                         children:nil
                                     fetchRequest:groupRequest
                                    relatedObject:group.objectID];
    }]
                                                    fetchRequest:nil
                                                   relatedObject:nil];

    SidebarItem *tags = [[SidebarItem alloc] initWithTitle:@"Popular Tags"
                                                symbolName:@"tag"
                                          dragResponseType:SidebarItemDragResponseNone
                                                  children:[testTags mapUsingBlock:^SidebarItem * _Nonnull(NSString * _Nonnull title) {
        return [[SidebarItem alloc] initWithTitle:title
                                       symbolName:nil
                                 dragResponseType:SidebarItemDragResponseNone
                                         children:nil
                                     fetchRequest:nil
                                    relatedObject:nil];
    }]
                                              fetchRequest:nil
                                             relatedObject:nil];

    NSFetchRequest *trashReequest = [NSFetchRequest fetchRequestWithEntityName:@"Asset"];
    [trashReequest setPredicate:[NSPredicate predicateWithFormat: @"deletedAt != nil"]];
    SidebarItem *trash = [[SidebarItem alloc] initWithTitle:@"Trash"
                                                 symbolName:@"trash"
                                           dragResponseType:SidebarItemDragResponseTrash
                                                   children:nil
                                               fetchRequest:trashReequest
                                              relatedObject:nil];

    SidebarItem *root = [[SidebarItem alloc] initWithTitle:@"toplevel"
                                                symbolName:nil
                                          dragResponseType:SidebarItemDragResponseNone
                                                  children:@[everything, favourites, groupsItem, tags, trash]
                                              fetchRequest:nil
                                             relatedObject:nil];

    return root;
}

@end
