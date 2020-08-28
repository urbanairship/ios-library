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

- (instancetype)initWithQueue:(dispatch_queue_t)queue context:(NSString *)context {
    self = [super init];

    if (self) {
        self.queue = queue;
        self.context = context;

        dispatch_queue_set_specific(queue, UADispatcherQueueSpecificKey, (__bridge void *)self.context, NULL);
    }

    return self;
}

+ (instancetype)dispatcherWithQueue:(dispatch_queue_t)queue context:(NSString *)context {
    return [[self alloc] initWithQueue:queue context:context];
}

+ (instancetype)mainDispatcher {
    static dispatch_once_t mainDispatcherOnceToken;

    dispatch_once(&mainDispatcherOnceToken, ^{
        mainDispatcher = [UADispatcher dispatcherWithQueue:dispatch_get_main_queue()
                                                   context:@"com.urbanairship.dispatcher.queue_specific_context.main"];
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
            dispatch_queue_t queue = dispatch_get_global_queue(qos, 0);
            UADispatcher *dispatcher = [UADispatcher dispatcherWithQueue:queue
                                                                 context:@"com.urbanairship.dispatcher.queue_specific_context.background"];
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

    NSString *ctx = [@"com.urbanairship.dispatcher.queue_specific_context.serial-" stringByAppendingString:[NSUUID UUID].UUIDString];
    return [self dispatcherWithQueue:queue context:ctx];
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

- (UADisposable *)dispatchAfter:(NSTimeInterval)delay block:(void (^)(void))block {
    if (delay < 0) {
        delay = 0;
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), self.queue, block);

    return [UADisposable disposableWithBlock:^{
        if (!dispatch_block_testcancel(block)) {
            dispatch_block_cancel(block);
        }
    }];
}

- (BOOL)isCurrentQueue {
    NSString *specific = (__bridge NSString *)dispatch_get_specific(UADispatcherQueueSpecificKey);
    return [self.context isEqualToString:specific];
}

@end
