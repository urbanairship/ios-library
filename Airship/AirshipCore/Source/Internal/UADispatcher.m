/* Copyright Airship and Contributors */

#import "UADispatcher.h"

/**
 * Key for associating GCD queues to contexts.
 */
static void *UADispatcherQueueSpecificKey = "com.urbanairsip.dispatcher.queue_specific_key";

@interface UADispatcher()
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, copy) NSString *context;
@end

@implementation UADispatcher

static UADispatcher *mainDispatcher;
static NSMutableDictionary *globalDispatchers;

- (instancetype)initWithQueue:(dispatch_queue_t)queue {
    self = [super init];

    if (self) {
        self.queue = queue;
        dispatch_queue_set_specific(queue, UADispatcherQueueSpecificKey, (__bridge void *)self, NULL);
    }

    return self;
}

+ (instancetype)dispatcherWithQueue:(dispatch_queue_t)queue {
    return [[self alloc] initWithQueue:queue];
}

+ (instancetype)mainDispatcher {
    static dispatch_once_t mainDispatcherOnceToken;

    dispatch_once(&mainDispatcherOnceToken, ^{
        mainDispatcher = [UADispatcher dispatcherWithQueue:dispatch_get_main_queue()];
    });

    return mainDispatcher;
}

+ (instancetype)globalDispatcher:(dispatch_qos_class_t)qos {
    static dispatch_once_t globalDispatcherOnceToken;

    dispatch_once(&globalDispatcherOnceToken, ^{
        globalDispatchers = [NSMutableDictionary dictionary];
    });

    @synchronized (globalDispatchers) {
        if (!globalDispatchers[@(qos)]) {
            UADispatcher *dispatcher = [UADispatcher dispatcherWithQueue:dispatch_get_global_queue(qos, 0)];
            globalDispatchers[@(qos)] = dispatcher;
            return dispatcher;
        }

        return globalDispatchers[@(qos)];
    }
}

+ (instancetype)globalDispatcher {
    return [self globalDispatcher:QOS_CLASS_BACKGROUND];
}

+ (instancetype)serialDispatcher:(dispatch_qos_class_t)qos {
    dispatch_queue_attr_t attributes = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, qos, 0);
    dispatch_queue_t queue = dispatch_queue_create("com.urbanairship.dispatcher.serial_queue", attributes);
    return [self dispatcherWithQueue:queue];
}

+ (instancetype)serialDispatcher {
    return [self serialDispatcher:QOS_CLASS_DEFAULT];
}

- (void)dispatchSync:(void (^)(void))block {
    dispatch_sync(self.queue, block);
}

- (void)doSync:(void (^)(void))block {
    if ([self isCurrentQueue]) {
        block();
    } else if (self == [UADispatcher mainDispatcher] && [NSThread isMainThread]) {
        block();
    } else {
        [self dispatchSync:block];
    }
}

- (void)dispatchAsyncIfNecessary:(void (^)(void))block {
    if ([self isCurrentQueue]) {
        block();
    } else {
        [self dispatchAsync:block];
    }
}

- (void)dispatchAsync:(void (^)(void))block {
    dispatch_async(self.queue, block);
}

- (UADisposable *)dispatchAfter:(NSTimeInterval)delay timebase:(UADispatcherTimeBase)timebase block:(void (^)(void))block {
    if (delay < 0) {
        delay = 0;
    }

    if (timebase == UADispatcherTimeBaseWall) {
        dispatch_after(dispatch_walltime(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), self.queue, block);
    } else {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), self.queue, block);
    }

    return [UADisposable disposableWithBlock:^{
        if (!dispatch_block_testcancel(block)) {
            dispatch_block_cancel(block);
        }
    }];
}

- (UADisposable *)dispatchAfter:(NSTimeInterval)delay block:(void (^)(void))block {
    return [self dispatchAfter:delay timebase:UADispatcherTimeBaseWall block:block];
}

- (BOOL)isCurrentQueue {
    return dispatch_get_specific(UADispatcherQueueSpecificKey) == (__bridge void *)(self);
}

@end
