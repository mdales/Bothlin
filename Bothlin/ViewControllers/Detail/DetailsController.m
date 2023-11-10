//
//  DetailsController.m
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 28/09/2023.
//

#import "DetailsController.h"
#import "Asset+CoreDataClass.h"

NSString * __nonnull const kPropertyColumnIdentifier = @"PropertyColumn";
NSString * __nonnull const kValueColumnIdentifier = @"ValueColumn";
NSString * __nonnull const kPropertyCellIdentifier = @"PropertyCell";
NSString * __nonnull const kValueCellIdentifier = @"ValueCell";

NSArray * __nonnull const kMainInfoTitles = @[@"Name", @"Created", @"Type"];
NSArray * __nonnull const kMainInfoProperties = @[@"name", @"created", @"type"];

@interface DetailsController ()

// Only access on mainQ
@property (nonatomic, strong, readwrite) Asset *item;

@end

@implementation DetailsController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)setItemForDisplay:(Asset *)item {
    dispatch_assert_queue(dispatch_get_main_queue());
    self.item = item;
    if (nil != item) {
        [self.notesView setStringValue:item.notes];
    }
    [self.detailsView reloadData];
}

- (IBAction)textFieldUpdated:(id)sender {
    NSLog(@"%@", [sender stringValue]);
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

@end
