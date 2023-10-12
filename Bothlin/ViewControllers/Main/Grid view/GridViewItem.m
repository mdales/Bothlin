//
//  GridViewItem.m
//  Bothlin
//
//  Created by Michael Dales on 11/10/2023.
//

#import "GridViewItem.h"
#import "ItemExtension.h"
#import "NSURL+SecureAccess.h"

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
    NSFilePromiseProvider *provider = [[NSFilePromiseProvider alloc] initWithFileType:self.item.type
                                                                             delegate:self];
    provider.userInfo = self.item;
    return provider;
}

- (NSImage*)draggingImageForDragSourceView:(DragSourceView *)dragSourceView {
    NSRect targetRect = [dragSourceView frame];
    NSImage *dragImage = [[NSImage alloc] initWithSize:targetRect.size];
    NSBitmapImageRep *imageRep = [self.imageView bitmapImageRepForCachingDisplayInRect:targetRect];
    if (nil != imageRep) {
        [self.imageView cacheDisplayInRect:targetRect
                          toBitmapImageRep:imageRep];
        [dragImage addRepresentation:imageRep];
    }
    return dragImage;
}

- (void)dragSourceView:(DragSourceView *)dragSourceView wasClicked:(NSInteger)count {
    if (1 == count) {
        NSIndexPath *index = [self.collectionView indexPathForItem:self];
        NSIndexSet *indexSet = [[NSIndexSet alloc] initWithIndex:(NSUInteger)index.item];
        [self.collectionView setSelectionIndexes:indexSet];
        // TODO: be less gross once you've finished replumbing
        [self.collectionView.delegate collectionView:self.collectionView
                          didSelectItemsAtIndexPaths:[NSSet setWithObject:index]];
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

- (void)filePromiseProvider:(NSFilePromiseProvider *)filePromiseProvider writePromiseToURL:(NSURL *)destinationURL completionHandler:(void (^)(NSError * _Nullable))completionHandler {
    Item *item = (Item*)filePromiseProvider.userInfo;
    if (nil == item) {
        return;
    }

    __block NSError *error = nil;
    NSURL *sourceURL = [item decodeSecureURL:&error];
    if (nil != error) {
        NSAssert(nil == sourceURL, @"both both error and url");
        completionHandler(error);
        return;
    }
    NSAssert(nil != sourceURL, @"got neither error nor url");

    __block BOOL success = NO;
    [sourceURL secureAccessWithBlock:^(NSURL * _Nonnull secureURL, __unused BOOL canAccess) {
        NSFileManager *fm = [NSFileManager defaultManager];
        success = [fm copyItemAtURL:secureURL
                              toURL:destinationURL
                              error:&error];
    }];
    if (nil != error) {
        NSAssert(NO == success, @"Got error and success from copy");
        completionHandler(error);
        return;
    }
    NSAssert(NO != success, @"Got no error and not succes from copy");

    completionHandler(nil);
}

@end
