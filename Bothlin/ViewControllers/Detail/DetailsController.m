//
//  DetailsController.m
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 28/09/2023.
//

#import "DetailsController.h"
#import "Asset+CoreDataClass.h"
#import "Tag+CoreDataClass.h"
#import "TagViewItem.h"

NSString * __nonnull const kPropertyColumnIdentifier = @"PropertyColumn";
NSString * __nonnull const kValueColumnIdentifier = @"ValueColumn";
NSString * __nonnull const kPropertyCellIdentifier = @"PropertyCell";
NSString * __nonnull const kValueCellIdentifier = @"ValueCell";

NSArray * __nonnull const kMainInfoTitles = @[@"Name", @"Created", @"Type"];
NSArray * __nonnull const kMainInfoProperties = @[@"name", @"created", @"type"];

@interface DetailsController ()

// Only access on mainQ
@property (nonatomic, strong, readwrite) Asset *item;
@property (nonatomic, strong, readwrite) NSArray<Tag *> *tags;

@end

@implementation DetailsController

- (void)setItemForDisplay:(Asset *)item {
    dispatch_assert_queue(dispatch_get_main_queue());
    self.item = item;
    if (nil != item) {
        [self.notesView setStringValue:item.notes];
        NSArray *tagsList = [item.tags allObjects];
        NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES];
        self.tags = [tagsList sortedArrayUsingDescriptors:@[sortDescriptor]];
    } else {
        [self.notesView setStringValue:@""];
        self.tags = @[];
    }
    [self.addTagButton setEnabled:nil != item];
    [self.detailsView reloadData];
    [self.tagCollectionView reloadData];
}

- (IBAction)textFieldUpdated:(id)sender {
    NSLog(@"%@", [sender stringValue]);
}

- (IBAction)addTag:(id)sender {
    [self.delegate addTagViaDetailsController:self];
}

#pragma mark - NSOutlineViewDataSource

- (NSInteger)outlineView:(__unused NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    if (nil == item) {
        return (NSInteger)[kMainInfoTitles count];
    }
    return 0;
}

- (id)outlineView:(__unused NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
    return kMainInfoTitles[(NSUInteger)index];
}

- (BOOL)outlineView:(__unused NSOutlineView *)outlineView isItemExpandable:(__unused id)item {
    return NO;
}

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    if ([tableColumn.identifier compare:kPropertyColumnIdentifier] == NSOrderedSame) {
        NSTableCellView *view = [outlineView makeViewWithIdentifier:kPropertyCellIdentifier owner:self];
        view.textField.stringValue = item;

        return view;


    } else if ([tableColumn.identifier compare:kValueColumnIdentifier] == NSOrderedSame) {
        NSTableCellView *view = [outlineView makeViewWithIdentifier:kValueCellIdentifier owner:self];
        if (nil == self.item) {
            view.textField.stringValue = @"";
        } else {
            // TODO: make robust!
            NSUInteger index = [kMainInfoTitles indexOfObject:item];
            NSString *property = kMainInfoProperties[index];
            id value = [self.item valueForKey:property];
            if ([value isKindOfClass:[NSString class]]) {
                view.textField.stringValue = value;
            } else {
                NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                [formatter setDateStyle:NSDateFormatterShortStyle];
                [formatter setTimeStyle:NSDateFormatterShortStyle];
                view.textField.stringValue = [formatter stringFromDate:value];
            }
        }

        return view;

    } else {
        NSAssert(NO, @"Got unexpected table column: %@", tableColumn.identifier);
    }
    return nil;
}

#pragma mark - NSOutlineViewDelegate

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item {
    return NO;
}


#pragma mark - NSCollectionViewDataSource

- (NSInteger)numberOfSectionsInCollectionView:(NSCollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return (nil == self.item) ? 0 : (NSInteger)[self.tags count];
}

- (NSCollectionViewItem *)collectionView:(NSCollectionView *)collectionView itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath {
    NSParameterAssert(nil != indexPath);
    NSAssert(NSNotFound != [indexPath item], @"Got empty index path");

    Tag *tag = [self.tags objectAtIndex:(NSUInteger)[indexPath item]];
    TagViewItem *item = [collectionView makeItemWithIdentifier:@"TagViewItem"
                                                  forIndexPath:indexPath];
    item.delegate = self;
    item.tag = tag;

    return item;
}


#pragma mark - NSCollectionViewDelegate



#pragma mark - NSCollectionViewDelegateFlowLayout

- (NSSize)collectionView:(NSCollectionView *)collectionView layout:(NSCollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    NSParameterAssert(nil != indexPath);
    NSAssert(NSNotFound != [indexPath item], @"Got empty index path");

    Tag *tag = [self.tags objectAtIndex:(NSUInteger)[indexPath item]];
    return [TagViewItem sizeForTagName:tag.name];
}


#pragma mark - TagViewItemDelegate

- (void)tagViewItemWasRemoved:(TagViewItem *)tagViewItem {
    
}

@end
