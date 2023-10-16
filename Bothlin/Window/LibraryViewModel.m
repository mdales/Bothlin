//
//  LibraryViewModel.m
//  Bothlin
//
//  Created by Michael Dales on 16/10/2023.
//

#import "LibraryViewModel.h"
#import "Item+CoreDataClass.h"
#import "Group+CoreDataClass.h"
#import "Helpers.h"

@interface LibraryViewModel ()

@property (nonatomic, strong, readonly, nonnull) dispatch_queue_t syncQ;
@property (nonatomic, strong, readonly, nonnull) NSManagedObjectContext *viewContext;

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
        self->_groups = result;
    });

    return YES;
}

- (BOOL)reloadItems:(NSError **)error {
    dispatch_assert_queue_not(self.syncQ);
    dispatch_assert_queue(dispatch_get_main_queue());

    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"Item"];
    NSPredicate *filter = [NSPredicate predicateWithFormat:@"deletedAt == nil"];
    [fetchRequest setPredicate:filter];
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

@end
