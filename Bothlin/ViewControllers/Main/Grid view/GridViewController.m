//
//  GridViewController.m
//  Bothlin
//
//  Created by Michael Dales on 28/09/2023.
//

#import "AppDelegate.h"
#import "GridViewController.h"
#import "Item+CoreDataClass.h"
#import "Helpers.h"

@interface GridViewController ()

@property (strong, nonatomic, readonly) dispatch_queue_t syncQ;
@property (strong, nonatomic, readonly) dispatch_queue_t thumbnailLoadQ;

// Access only on syncQ
@property (strong, nonatomic, readwrite) NSArray<Item *> *contents;
@property (strong, nonatomic, readwrite) NSDictionary<NSManagedObjectID *, NSImage *> *thumbnailCache;

@end

@implementation GridViewController

- (instancetype)initWithNibName:(NSNibName)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (nil != self) {
        self->_syncQ = dispatch_queue_create("com.digitalflapjack.GridViewController.syncQ", DISPATCH_QUEUE_SERIAL);
        self->_thumbnailLoadQ = dispatch_queue_create("com.digitalflapjack.GridViewController.thumbnailLoadQ", DISPATCH_QUEUE_CONCURRENT);
        self->_contents = [[NSArray alloc] init];
        self->_thumbnailCache = [[NSDictionary alloc] init];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    NSError *error = nil;
    [self reloadData: &error];
    if (nil != error) {
        NSLog(@"Failed to load data: %@", error.localizedDescription);
    }
    [self.collectionView reloadData];
}

#pragma mark - Data management

- (BOOL)reloadData: (NSError **)error {
    AppDelegate *appDelegate = (AppDelegate *)([NSApplication sharedApplication].delegate);
    NSManagedObjectContext *context = appDelegate.persistentContainer.viewContext;

    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName: @"Item"];
    NSPredicate *filter = [NSPredicate predicateWithFormat: @"deletedAt == nil"];
    [fetchRequest setPredicate: filter];
    NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey: @"created"
                                                           ascending: YES];
    [fetchRequest setSortDescriptors: @[sort]];

    NSError *innerError = nil;
    NSArray<Item *> *result = [context executeFetchRequest: fetchRequest
                                                     error: &innerError];
    if (nil != innerError) {
        NSAssert(nil == result, @"Got error and fetch results.");
        if (nil != error) {
            *error = innerError;
        }
        return NO;
    }
    NSAssert(nil != result, @"Got no error and no fetch results.");

    @weakify(self);
    dispatch_async(self.syncQ, ^{
        @strongify(self);
        if (nil == self) {
            return;
        }
        self.contents = result;

        @weakify(self);
        dispatch_async(dispatch_get_main_queue(), ^{
            @strongify(self);
            if (nil == self) {
                return;
            }
            [self.collectionView reloadData];
        });
    });

    return YES;
}

#pragma mark - NSCollectionViewDataSource

- (NSInteger)numberOfSectionsInCollectionView:(NSCollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    __block NSUInteger count = 0;
    dispatch_sync(self.syncQ, ^{
        count = [self.contents count];
    });

    return (NSInteger)count;
}

- (NSCollectionViewItem *)collectionView:(NSCollectionView *)collectionView itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath {
    dispatch_assert_queue(dispatch_get_main_queue());
    dispatch_assert_queue_not(self.syncQ);

    __block Item *item = nil;
    dispatch_sync(self.syncQ, ^{
        item = [self.contents objectAtIndex: (NSUInteger)indexPath.item];
    });

    LibraryGridViewItem *viewItem = [collectionView makeItemWithIdentifier: @"LibraryGridViewItem" forIndexPath: indexPath];
    viewItem.delegate = self;
    viewItem.textField.stringValue = item.name;

    __block NSImage *thumbnail = nil;
    dispatch_sync(self.syncQ, ^{
        thumbnail = self.thumbnailCache[item.objectID];
    });

    if (nil == thumbnail) {
        NSString *thumbnailPath = item.thumbnailPath;
        @weakify(self);
        @weakify(viewItem);
        dispatch_async(self.thumbnailLoadQ, ^{
            @strongify(self);
            if (nil == self) {
                return;
            }
            NSImage *thumbnail = [[NSImage alloc] initByReferencingFile: thumbnailPath];
            if (nil == thumbnail) {
                thumbnail = [NSImage imageWithSystemSymbolName: @"exclamationmark.square" accessibilityDescription: nil];
            }

            dispatch_sync(self.syncQ, ^{
                NSMutableDictionary<NSManagedObjectID *, NSImage *> *tmp = [NSMutableDictionary dictionaryWithDictionary: self.thumbnailCache];
                tmp[item.objectID] = thumbnail;
                self.thumbnailCache = [NSDictionary dictionaryWithDictionary: tmp];
            });

            dispatch_async(dispatch_get_main_queue(), ^{
                @strongify(viewItem);
                if (nil == viewItem) {
                    return;
                }
                viewItem.imageView.image = thumbnail;
            });
        });

        thumbnail = [NSImage imageWithSystemSymbolName: @"photo.artframe" accessibilityDescription: nil];
    }

    viewItem.imageView.image = thumbnail;

    return viewItem;
}

#pragma mark - NSCollectionViewDelegate

- (void)collectionView:(NSCollectionView *)collectionView didSelectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths {
    NSAssert(1 == [indexPaths count], @"User selected more/less than one item: %lu", [indexPaths count]);
    NSIndexPath *indexPath = [indexPaths anyObject];

    __block Item *item = nil;
    dispatch_sync(self.syncQ, ^{
        item = self.contents[(NSUInteger)indexPath.item];
    });

    self.selectedItem = item;
    if (nil != self.delegate) {
        [self.delegate gridViewController: self
                       selectionDidChange: item];
    }
}

#pragma mark - LibraryGridViewItemDelegate

- (void)gridViewItemWasDoubleClicked:(LibraryGridViewItem *)gridViewItem {
    NSLog(@"double clicked");
}


@end
