//
//  KVOBox.m
//  Bothlin
//
//  Created by Michael Dales on 18/10/2023.
//

#import "KVOBox.h"
#import "Helpers.h"

@interface KVOBox ()

@property (nonatomic, strong, readonly) id object;
@property (nonatomic, copy, readonly) NSString *keyPath;
@property (nonatomic, strong, readonly) dispatch_queue_t syncQ;

// Only access on syncQ
@property (nonatomic, readwrite) BOOL started;
@property (nonatomic, strong, readwrite) void (^block)(NSDictionary *);


@end

@implementation KVOBox

+ (instancetype)observeObject:(id)object
                      keyPath:(NSString *)keyPath {
    NSParameterAssert(nil != object);
    NSParameterAssert(nil != keyPath);
    return [[KVOBox alloc] initWithObserveObject:object
                                         keyPath:keyPath];
}

- (instancetype)initWithObserveObject:(id)object
                              keyPath:(NSString *)keyPath {
    self = [super init];
    if (nil != self) {
        self->_block = nil;
        self->_object = object;
        self->_keyPath = keyPath;
        self->_syncQ = dispatch_queue_create("com.digitalflapjack.KVOBox", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)dealloc {
    NSAssert(NO == self.started, @"KVOBox still observing object when destroyed!");
}

- (BOOL)startWithBlock:(void (^)(NSDictionary *))block
                 error:(NSError **)error {
    __block BOOL success = NO;
    __block NSError *innerError = nil;
    dispatch_sync(self.syncQ, ^{
        if (NO != self.started) {
            innerError = [NSError errorWithDomain:NSPOSIXErrorDomain
                                             code:EINPROGRESS
                                         userInfo:nil];
            success = NO;
            return;
        }
        self.block = block;
        [self.object addObserver:self
                      forKeyPath:self.keyPath
                         options:NSKeyValueObservingOptionInitial
                         context:(__bridge void *)self];
        success = YES;
        self.started = YES;
    });
    if (nil != error) {
        *error = innerError;
    }
    return success;
}

- (BOOL)stop:(NSError **)error {
    __block BOOL success = NO;
    __block NSError *innerError = nil;
    dispatch_sync(self.syncQ, ^{
        if (NO == self.started) {
            innerError = [NSError errorWithDomain:NSPOSIXErrorDomain
                                             code:EINVAL
                                         userInfo:nil];
            success = NO;
            return;
        }
        [self.object removeObserver:self forKeyPath:self.keyPath];
        self.started = NO;
        self.block = nil;
        success = YES;
    });
    if (nil != error) {
        *error = innerError;
    }
    return success;
}

- (void)observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context {

    if (context == (__bridge void *)self) {
        @weakify(self);
        dispatch_async(self.syncQ, ^{
            @strongify(self);
            if (nil == self) {
                return;
            }
            void (^block)(NSDictionary *) = self.block;
            dispatch_async(dispatch_get_main_queue(), ^{
                block(change);
            });
        });
    }
}


@end
