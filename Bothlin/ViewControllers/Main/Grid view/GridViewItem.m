//
//  GridViewItem.m
//  Bothlin
//
//  Created by Michael Dales on 11/10/2023.
//

#import "GridViewItem.h"
#import "ItemExtension.h"

@interface GridViewItem ()

@property (nonatomic, strong, readonly) NSOperationQueue *workQueue;

@end

@implementation GridViewItem

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (nil != self) {
        self->_workQueue = [[NSOperationQueue alloc] init];
        [self->_workQueue setQualityOfService:NSQualityOfServiceUserInitiated];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    NSClickGestureRecognizer *doubleClickGesture = [[NSClickGestureRecognizer alloc] initWithTarget:self
                                                                                             action:@selector(onDoubleClick:)];
    [doubleClickGesture setNumberOfClicksRequired:2];
    [doubleClickGesture setDelaysPrimaryMouseButtonEvents:NO];
    [self.view addGestureRecognizer:doubleClickGesture];

    self.dragSourceView.delegate = self;
}


- (void)setSelected:(BOOL)value {
    [super setSelected:value];
    NSColor *bgColor = value ? [NSColor selectedControlColor] : [NSColor clearColor];
    self.view.layer.backgroundColor = bgColor.CGColor;
}

- (void)onDoubleClick:(NSGestureRecognizer *)sender {
    dispatch_assert_queue(dispatch_get_main_queue());
    [self.delegate gridViewItemWasDoubleClicked:self];
}

#pragma mark - DragSourceViewDelegate

- (id<NSPasteboardWriting>)pasteboardWriterForDragSourceView:(DragSourceView *)dragSourceView {
    NSFilePromiseProvider *provider = [[NSFilePromiseProvider alloc] initWithFileType:(NSString*)kUTTypePNG
                                                                             delegate:self];
    return provider;
}

- (NSImage*)draggingImageForDragSourceView:(DragSourceView *)dragSourceView {
    return self.imageView.image;
}

- (void)dragSourceView:(DragSourceView *)dragSourceView wasClicked:(NSInteger)count {
    if (1 == count) {
        NSIndexPath *index = [self.collectionView indexPathForItem:self];
        NSIndexSet *indexSet = [[NSIndexSet alloc] initWithIndex:(NSUInteger)index.item];
        [self.collectionView setSelectionIndexes:indexSet];
    } else if (2 == count) {
        [self.delegate gridViewItemWasDoubleClicked:self];
    }
}

#pragma mark - NSFilePromiseProviderDelegate

- (NSString*)filePromiseProvider:(NSFilePromiseProvider *)filePromiseProvider
                 fileNameForType:(NSString *)fileType {
    return self.item.name;
}

- (NSOperationQueue*)operationQueueForFilePromiseProvider:(NSFilePromiseProvider *)filePromiseProvider {
    return self.workQueue;
}

- (void)filePromiseProvider:(NSFilePromiseProvider *)filePromiseProvider writePromiseToURL:(NSURL *)url completionHandler:(void (^)(NSError * _Nullable))completionHandler {
    NSLog(@"doing export to %@", url);
    completionHandler([NSError errorWithDomain:NSPOSIXErrorDomain
                                          code:ENOTRECOVERABLE
                                      userInfo:@{}]);
}

@end
