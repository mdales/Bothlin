//
//  DetailsController.m
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 28/09/2023.
//

#import "DetailsController.h"
#import "Item+CoreDataClass.h"

NSString * __nonnull const kPropertyColumnIdentifier = @"PropertyColumn";
NSString * __nonnull const kValueColumnIdentifier = @"ValueColumn";
NSString * __nonnull const kPropertyCellIdentifier = @"PropertyCell";
NSString * __nonnull const kValueCellIdentifier = @"ValueCell";

NSArray * __nonnull const kMainInfoTitles = @[@"Name", @"Created", @"Type"];
NSArray * __nonnull const kMainInfoProperties = @[@"name", @"created", @"type"];

@interface DetailsController ()

// Only access on mainQ
@property (nonatomic, strong, readwrite) Item *item;

@end

@implementation DetailsController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)setItemForDisplay:(Item *)item {
    self.item = item;
    [self.detailsView reloadData];
}

#pragma mark - NSOutlineViewDataSource

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    if (nil == item) {
        return (NSInteger)[kMainInfoTitles count];
    }
    return 0;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
    return kMainInfoTitles[(NSUInteger)index];
}


#pragma mark - NSOutlineViewDelegate

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

@end
