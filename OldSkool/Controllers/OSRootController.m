//
//  OSRootController.m
//  OldSkool
//
//  Created by Michael Dales on 19/09/2023.
//

#import "OSRootController.h"

@interface OSRootController ()

//@property (strong, nonatomic, readonly) dispatch_queue_t syncQ;
@property (strong, nonatomic, readonly) OSLibraryController *libraryController;

@end

@implementation OSRootController

- (instancetype) init {
    self = [super init];
//    self->_syncQ = dispatch_queue_create("com.this.that.OSRootController.syncQ", DISPATCH_QUEUE_SERIAL);
    self->_libraryController = [[OSLibraryController alloc] init];

    return self;
}

- (void)awakeFromNib {
    NSLog(@"awake from nib");
    self.libraryView.delegate = self.libraryController;
    self.libraryView.dataSource = self.libraryController;

    NSError *error = nil;
    [self.libraryController reloadData: &error];
    if (nil != error) {
        NSLog(@"Failed to load data: %@", error);
        return;
    }

    [self.libraryView reloadData];
}

- (IBAction)addItem: (id)sender {

    NSOpenPanel* panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = NO;
    panel.canChooseDirectories = YES;
    panel.canCreateDirectories = NO;

    [panel beginSheetModalForWindow: self.libraryView.window completionHandler: ^(NSInteger result) {
        if (NSModalResponseOK == result) {
            NSArray<NSURL *> *urls = [panel URLs];

            // TODO: be better
            NSAssert(urls.count == 1, @"Expected 1 directory, got %lu", (unsigned long)urls.count);

            NSError *error = nil;
            [self.libraryController importDirectoryContentsAtURL: urls.firstObject
                                                           error: &error];
            if (nil != error) {
                NSLog(@"Failed to load directory: %@", error.localizedDescription);
                return;
            }
            [self.libraryController reloadData: &error];
            if (nil != error) {
                NSLog(@"Failed to reload library: %@", error.localizedDescription);
                return;
            }
            [self.libraryView reloadData];
        }
    }];
}

#pragma mark NSSplitViewDelegate

- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex {
    return proposedMinimumPosition + 100;
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMaximumPosition ofSubviewAt:(NSInteger)dividerIndex {
    return proposedMaximumPosition - 100;
}

- (BOOL)splitView:(NSSplitView *)splitView canCollapseSubview:(NSView *)subview {
    NSAssert(nil != self.splitView, @"Split view outlet not set.");

    NSUInteger index = [self.splitView.subviews indexOfObject: subview];
    return index != 1;
}

@end

