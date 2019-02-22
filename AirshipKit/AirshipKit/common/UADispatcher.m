/* Copyright Urban Airship and Contributors */

#import "UADispatcher+Internal.h"

/**
 * Custom key for associating GCD queues to dispatcher types
 */
static void *UADispatcherQueueSpecificKey = "com.urbanairsip.dispatcher.queue_specific_key";

/**
 * Represents the main queue.
 */
static void *UADispatcherQueueSpecificContextMain = "com.urbanairship.dispatcher.queue_specific_context.main";

/**
 * Represents the background queue.
 */
static void *UADispatcherQueueSpecificContextBackground = "com.urbanairship.dispatcher.queue_specific_context.background";

/**
 * Enum representing the possible dispatcher types.
 */
typedef NS_ENUM(NSUInteger, UADispatcherType) {
    /**
     * Represents the main dispatcher.
     */
    UADispatcherTypeMain = 0,
    /**
     * Represents the background dispatcher.
     */
    UADispatcherTypeBackground = 1,
};

@interface UADispatcher()
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, assign) UADispatcherType type;
@end

@implementation UADispatcher

- (instancetype)initWithQueue:(dispatch_queue_t)queue type:(UADispatcherType)type {
    self = [super init];

    if (self) {
        self.queue = queue;
        self.type = type;
    }

    return self;
}

+ (instancetype)mainDispatcher {
    static dispatch_once_t mainDispatcherOnceToken;
    static UADispatcher *mainDispatcher;

    dispatch_once(&mainDispatcherOnceToken, ^{
        mainDispatcher = [UADispatcher dispatcherWithQueue:dispatch_get_main_queue() type:UADispatcherTypeMain];
        dispatch_queue_set_specific(dispatch_get_main_queue(), UADispatcherQueueSpecificKey, UADispatcherQueueSpecificContextMain, NULL);
    });

    return mainDispatcher;
}

+ (instancetype)backgroundDispatcher {
    static dispatch_once_t backgroundDispatcherOnceToken;
    static UADispatcher *backgroundDispatcher;

    dispatch_once(&backgroundDispatcherOnceToken, ^{
        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
        backgroundDispatcher = [UADispatcher dispatcherWithQueue:queue type:UADispatcherTypeBackground];
        dispatch_queue_set_specific(queue, UADispatcherQueueSpecificKey, UADispatcherQueueSpecificContextBackground, NULL);
    });

    return backgroundDispatcher;
}

+ (instancetype)dispatcherWithQueue:(dispatch_queue_t)queue type:(UADispatcherType)type {
    return [[self alloc] initWithQueue:queue type:type];
}

- (void)dispatchSync:(void (^)(void))block {
    dispatch_sync(self.queue, block);
}

- (void)doSync:(void (^)(void))block {
    if ([self isCurrentQueueType]) {
        block();
    } else {
        [self dispatchSync:block];
    }
}

- (void)dispatchAsyncIfNecessary:(void (^)(void))block {
    if ([self isCurrentQueueType]) {
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

- (BOOL)isCurrentQueueType {
    void *context = self.type == UADispatcherTypeMain ? UADispatcherQueueSpecificContextMain : UADispatcherQueueSpecificContextBackground;

    return dispatch_get_specific(UADispatcherQueueSpecificKey) == context;
}

@end
