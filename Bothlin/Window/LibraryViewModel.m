//
//  LibraryViewModel.m
//  Bothlin
//
//  Created by Michael Dales on 16/10/2023.
//

#import "LibraryViewModel.h"
#import "Item+CoreDataClass.h"
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

@property (nonatomic, strong, readwrite) NSArray<Item *> *contents;
@property (nonatomic, strong, readwrite) NSArray<Group *> *groups;
@property (nonatomic, strong, readwrite) SidebarItem *sidebarItems;

@end


@implementation LibraryViewModel

@synthesize contents = _contents;
@synthesize selected = _selected;
@synthesize groups = _groups;
@synthesize selectedSidebarItem = _selectedSidebarItem;

- (instancetype)initWithViewContext:(NSManagedObjectContext *)viewContext {
    self = [super init];
    if (nil != self) {
        self->_syncQ = dispatch_queue_create("com.digitalflapjack.LibraryViewModel.syncQ", DISPATCH_QUEUE_SERIAL);
        self->_viewContext = viewContext;
        self->_contents = @[];
        self->_selected = nil;
        self->_sidebarItems = [LibraryViewModel buildMenuWithGroups:@[]];
    }
    return self;
}

#pragma mark - getters

- (NSArray<Item *> *)contents {
    dispatch_assert_queue_not(self.syncQ);
    __block NSArray<Item *> *val = nil;
    dispatch_sync(self.syncQ, ^{
        val = self->_contents;
    });
    return val;
}

- (Item *)selected {
    dispatch_assert_queue_not(self.syncQ);
    __block Item *val = nil;
    dispatch_sync(self.syncQ, ^{
        val = self->_selected;
    });
    return val;
}

- (void)setSelected:(Item *)selected {
    dispatch_assert_queue_not(self.syncQ);
    dispatch_sync(self.syncQ, ^{
        if (self->_selected != selected) {
            self->_selected = selected;
        }
    });
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
        BOOL success = [self reloadItems:&error];
        if (nil != error) {
            NSAssert(NO == success, @"Got error but also success");
            [self.delegate libraryViewModel:self
                           hadErrorOnUpdate:error];
        }
        NSAssert(NO != success, @"Got no error and no success");
    });
}

#pragma mark - LibraryControllerDelegate

- (void)libraryDidUpdate:(NSDictionary *)changeNotificationData {
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

    if ([classes containsObject:NSStringFromClass([Item class])]) {
        // TODO: This is all very crude, but let's get something working
        // before we end up down a perfect diffing rabbit hole.
        dispatch_sync(self.syncQ, ^{
            NSError *error = nil;
            BOOL success = [self reloadItems:&error];
            if (nil != error) {
                [self.delegate libraryViewModel:self
                               hadErrorOnUpdate:error];
            }
            NSAssert(NO != success, @"Got no error and no success");
        });
    }
}

- (void)thumbnailGenerationFailedWithError:(NSError *)error {
    // TODO: this is refactor fallout, should be on RootWindowController
    NSParameterAssert(nil != error);
    NSAlert *alert = [NSAlert alertWithError:error];
    [alert runModal];
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

- (BOOL)reloadItems:(NSError **)error {
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
    NSArray<Item *> *result = [self.viewContext executeFetchRequest:request
                                                              error:&innerError];
    if (nil != innerError) {
        NSAssert(nil == result, @"Got error and fetch results.");
        if (nil != error) {
            *error = innerError;
        }
        return NO;
    }
    NSAssert(nil != result, @"Got no error and no fetch results.");

    self.contents = result;
    if ((nil == self->_selected) || ([result indexOfObject:self->_selected] == NSNotFound)) {
        self->_selected = [result firstObject];
    }

    [self didChangeValueForKey:@"contents"];

    return YES;
}

+ (SidebarItem * _Nonnull)buildMenuWithGroups:(NSArray<Group *> * _Nonnull)groups {
    NSFetchRequest *everythingRequest = [NSFetchRequest fetchRequestWithEntityName:@"Item"];
    [everythingRequest setPredicate:[NSPredicate predicateWithFormat: @"deletedAt == nil"]];
    SidebarItem *everything = [[SidebarItem alloc] initWithTitle:@"Everything"
                                                      symbolName:@"shippingbox"
                                                dragResponseType:SidebarItemDragResponseNone
                                                        children:nil
                                                    fetchRequest:everythingRequest
                                                   relatedObject:nil];

    NSFetchRequest *favouriteRequest = [NSFetchRequest fetchRequestWithEntityName:@"Item"];
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
        NSFetchRequest *groupRequest = [NSFetchRequest fetchRequestWithEntityName:@"Item"];
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

    NSFetchRequest *trashReequest = [NSFetchRequest fetchRequestWithEntityName:@"Item"];
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
