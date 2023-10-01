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

// Access only on syncQ
@property (strong, nonatomic, readwrite) NSArray<Item *> *contents;

@end

@implementation GridViewController

- (instancetype)initWithNibName:(NSNibName)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (nil != self) {
        self->_syncQ = dispatch_queue_create("com.digitalflapjack.GridViewController.syncQ", DISPATCH_QUEUE_SERIAL);
        self->_contents = [[NSArray alloc] init];
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
    [fetchRequest setSortDescriptors: [NSArray arrayWithObject: sort]];

    NSError *innerError = nil;
    NSArray<Item *> *result = [context executeFetchRequest: fetchRequest
                                                     error: &innerError];
    if (nil != innerError) {
        NSAssert(nil == result, @"Got error and fetch results.");
        if (nil != error) {
            *error = innerError;
        }
        return FALSE;
    }
    NSAssert(nil != result, @"Got no error and no fetch results.");

    @weakify(self);
    dispatch_async(self.syncQ, ^{
        @strongify(self);
        if (nil == self) {
            return;
        }
        self.contents = result;
    });

    [self.collectionView reloadData];

    return TRUE;
}

#pragma mark - NSCollectionViewDataSource

- (NSInteger)numberOfSectionsInCollectionView:(NSCollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    __block NSInteger count = 0;
    dispatch_sync(self.syncQ, ^{
        count = self.contents.count;
    });

    return count;
}

- (NSCollectionViewItem *)collectionView:(NSCollectionView *)collectionView itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath {
    __block Item *item = nil;
    dispatch_sync(self.syncQ, ^{
        item = [self.contents objectAtIndex: indexPath.item];
    });


    NSCollectionViewItem *viewItem = [collectionView makeItemWithIdentifier: @"OSLibraryViewItem" forIndexPath: indexPath];
    viewItem.textField.stringValue = item.name;

    NSString *thumbnailPath = item.thumbnailPath;
    if (nil == thumbnailPath) {
        viewItem.imageView.image = [NSImage imageWithSystemSymbolName: @"photo.artframe" accessibilityDescription: nil];
    } else {
        NSImage *thumbnail = [[NSImage alloc] initByReferencingFile: thumbnailPath];
        if (nil == thumbnail) {
            thumbnail = [NSImage imageWithSystemSymbolName: @"exclamationmark.square" accessibilityDescription: nil];
        }
        viewItem.imageView.image = thumbnail;
    }

//    BOOL canAccess = [path startAccessingSecurityScopedResource];
//    if (canAccess) {
//        NSImage *image = [[NSImage alloc] initByReferencingURL: path];
//        // TODO: fix - if we don't copy the data we have to hold onto the security scope indefinitely
//        // but this is clearly wasteful.
//        NSImage *copyImage = [[NSImage alloc] initWithData: image.TIFFRepresentation];
//        viewItem.imageView.image = copyImage;
//
//        [path stopAccessingSecurityScopedResource];
//    } else {
//        // TODO: Show damaged preview thingy here
//        NSLog(@"Failed to get access");
//    }

    return viewItem;
}

#pragma mark - NSCollectionViewDelegate

- (void)collectionView:(NSCollectionView *)collectionView didSelectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths {
    for (NSIndexPath *index in indexPaths) {
//        NSLog(@"%ld %ld -> selected", (long)index.section, (long)index.item);
    }
}


- (void)collectionView:(NSCollectionView *)collectionView didDeselectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths {
    for (NSIndexPath *index in indexPaths) {
//        NSLog(@"%ld %ld -> deselected", (long)index.section, (long)index.item);
    }
}

//- (void)collectionView:(NSCollectionView *)collectionView didChangeItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths toHighlightState:(NSCollectionViewItemHighlightState)highlightState {
//    for (NSIndexPath *index in indexPaths) {
//        NSLog(@"%ld %ld -> %ld", (long)index.section, (long)index.item, (long)highlightState);
//    }
//}

@end
