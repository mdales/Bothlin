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
    __block NSArray<Item *> *val;
    dispatch_sync(self.syncQ, ^{
        val = self->_contents;
    });
    return val;
}

- (Item *)selected {
    dispatch_assert_queue_not(self.syncQ);
    __block Item *val;
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

#pragma mark - LibraryControllerDelegate

- (void)libraryDidUpdate:(NSDictionary *)changeNotificationData {
    dispatch_assert_queue(dispatch_get_main_queue());

    // TODO: differentiate between inserts and updates to make the UI nicer
    // For now we at least check which class types have been updated to
    // minimise UI churn
    NSArray<NSManagedObjectID *> *objects = changeNotificationData[NSInsertedObjectsKey];
    if (nil == objects) {
        objects = @[];
    }
    NSArray<NSManagedObjectID *> *updated = changeNotificationData[NSUpdatedObjectsKey];
    if (nil != updated) {
        objects = [objects arrayByAddingObjectsFromArray: updated];
    }

    NSArray<NSString *> *allClasses = [objects mapUsingBlock:^id _Nonnull(NSManagedObjectID * _Nonnull object) {
        return [[object entity] name];
    }];
    NSSet<NSString *> *classes = [NSSet setWithArray:allClasses];

    if ([classes containsObject:NSStringFromClass([Group class])]) {
        NSError *error = nil;
        BOOL success = [self reloadGroups:&error];
        if (nil != error) {
            // TODO: this is refactor fallout, should be on RootWindowController
            NSAssert(NO == success, @"Got error and success");
            NSAlert *alert = [NSAlert alertWithError:error];
            [alert runModal];
            return;
        }
        NSAssert(NO != success, @"Got no error and no success");
        //    [self.sidebar setSidebarTree:self.viewModel.sidebarItems];
    }

    if ([classes containsObject:NSStringFromClass([Item class])]) {
        //    NSFetchRequest *fetchRequest = [self.sidebar selectedOption];
        //    success = [self reloadItemsWithFetchRequest:fetchRequest
        //                                          error:&error];
        //    if (nil != error) {
        //        NSAssert(NO == success, @"Got error and success");
        //        NSAlert *alert = [NSAlert alertWithError:error];
        //        [alert runModal];
        //        return;
        //    }
        //    NSAssert(NO != success, @"Got no error and no success");

        //    [self.itemsDisplay setItems:self.viewModel.contents
        //                   withSelected:self.viewModel.selected];
        //    [self.details setItemForDisplay:self.viewModel.selected];
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

- (BOOL)reloadItemsWithFetchRequest:(NSFetchRequest *)fetchRequest
                              error:(NSError **)error {
    dispatch_assert_queue_not(self.syncQ);
    dispatch_assert_queue(dispatch_get_main_queue());

    NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"created"
                                                           ascending:YES];
    [fetchRequest setSortDescriptors:@[sort]];

    NSError *innerError = nil;
    NSArray<Item *> *result = [self.viewContext executeFetchRequest:fetchRequest
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
        self->_contents = result;
        self->_selected = [result firstObject];
    });

    return YES;
}

+ (SidebarItem * _Nonnull)buildMenuWithGroups:(NSArray<Group *> * _Nonnull)groups {
    NSFetchRequest *everythingRequest = [NSFetchRequest fetchRequestWithEntityName:@"Item"];
    [everythingRequest setPredicate:[NSPredicate predicateWithFormat: @"deletedAt == nil"]];
    SidebarItem *everything = [[SidebarItem alloc] initWithTitle:@"Everything"
                                                      symbolName:@"shippingbox"
                                                        children:nil
                                                    fetchRequest:everythingRequest];

    NSFetchRequest *favouriteRequest = [NSFetchRequest fetchRequestWithEntityName:@"Item"];
    [favouriteRequest setPredicate:[NSPredicate predicateWithFormat: @"favourite == YES"]];
    SidebarItem *favourites = [[SidebarItem alloc] initWithTitle:@"Favourites"
                                                      symbolName:@"heart"
                                                        children:nil
                                                    fetchRequest:favouriteRequest];

    SidebarItem *groupsItem = [[SidebarItem alloc] initWithTitle:@"Groups"
                                                      symbolName:@"folder"
                                                        children:[groups mapUsingBlock:^SidebarItem * _Nonnull(Group * _Nonnull group) {
        NSFetchRequest *groupRequest = [NSFetchRequest fetchRequestWithEntityName:@"Item"];
        [groupRequest setPredicate:[NSPredicate predicateWithFormat: @"group == %@", group]];
        return [[SidebarItem alloc] initWithTitle:group.name
                                       symbolName:nil
                                         children:nil
                                     fetchRequest:groupRequest];
    }]
                                                    fetchRequest: nil];

    SidebarItem *tags = [[SidebarItem alloc] initWithTitle:@"Popular Tags"
                                                symbolName:@"tag"
                                                  children:[testTags mapUsingBlock:^SidebarItem * _Nonnull(NSString * _Nonnull title) {
        return [[SidebarItem alloc] initWithTitle:title
                                       symbolName:nil
                                         children:nil
                                     fetchRequest:nil];
    }]
                                              fetchRequest:nil];

    NSFetchRequest *trashReequest = [NSFetchRequest fetchRequestWithEntityName:@"Item"];
    [trashReequest setPredicate:[NSPredicate predicateWithFormat: @"deletedAt != nil"]];
    SidebarItem *trash = [[SidebarItem alloc] initWithTitle:@"Trash"
                                                 symbolName:@"trash"
                                                   children:nil
                                               fetchRequest:trashReequest];

    SidebarItem *root = [[SidebarItem alloc] initWithTitle:@"toplevel"
                                                symbolName:nil
                                                  children:@[everything, favourites, groupsItem, tags, trash]
                                              fetchRequest:nil];

    return root;
}

@end
