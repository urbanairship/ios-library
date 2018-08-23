/* Copyright 2018 Urban Airship and Contributors */

#import "UADispatcher+Internal.h"

@interface UADispatcher()
@property (nonatomic, strong) dispatch_queue_t queue;
@end

@implementation UADispatcher

- (instancetype)initWithQueue:(dispatch_queue_t)queue {
    self = [super init];
    if (self) {
        self.queue = queue;
    }

    return self;
}

+ (instancetype)mainDispatcher {
    static dispatch_once_t onceToken;
    static UADispatcher *mainDispatcher;
    dispatch_once(&onceToken, ^{
        mainDispatcher = [UADispatcher dispatcherWithQueue:dispatch_get_main_queue()];
    });

    return mainDispatcher;
}

+ (instancetype)dispatcherWithQueue:(dispatch_queue_t)queue {
    return [[self alloc] initWithQueue:queue];
}

- (void)dispatchSync:(void (^)(void))block {
    dispatch_sync(self.queue, block);
}

- (void)dispatchAsync:(void (^)(void))block {
    dispatch_async(self.queue, block);
}

- (void)dispatchAfter:(NSTimeInterval)delay block:(void (^)(void))block {
    if (delay > 0) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay * NSEC_PER_SEC), self.queue, block);
    } else {
        dispatch_async(self.queue, block);
    }
}

@end
