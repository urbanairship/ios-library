/* Copyright Airship and Contributors */


#import <Foundation/Foundation.h>
#import "UADisposable.h"

/**
 * Dispatcher time bases.
 * @note For internal use only. :nodoc:
 */
typedef NS_ENUM(NSUInteger, UADispatcherTimeBase) {
    /**
     * Wall time.
     */
    UADispatcherTimeBaseWall,

    /**
     * System time.
     */
    UADispatcherTimeBaseSystem,
};

/**
 * Utility class that wraps a dispatch queue and related GCD calls
 * @note For internal use only. :nodoc:
 */
@interface UADispatcher : NSObject

NS_ASSUME_NONNULL_BEGIN

/**
 * Shared dispatcher that dispatches on the main queue.
 *
 * @return The shared main dispatcher.
 */
+ (instancetype)mainDispatcher;

/**
 * Shared dispatcher that dispatches on a global concurrent queue with background QOS.
 *
 * @return The shared background dispatcher.
 */
+ (instancetype)globalDispatcher;

/**
 * Shared dispatcher that dispatches on a global concurrent queue with the provided QOS.
 *
 * @param qos The QOS
 */
+ (instancetype)globalDispatcher:(dispatch_qos_class_t)qos;

/**
 * Dispatcher that dispatches on a private serial queue with standard QOS.
 */
+ (instancetype)serialDispatcher;

/**
 * Dispatcher that dispatches on a private serial queue with the provided QOS
 *
 * @param qos The QOS.
 */
+ (instancetype)serialDispatcher:(dispatch_qos_class_t)qos;

/**
 * Dispatches after a delay, scheduled in wall time. If the delay <= 0, the block will
 * be dispatched asynchronously instead.
 *
 * @param delay The delay in seconds.
 * @param block The block to dispatch.
 */
- (UADisposable *)dispatchAfter:(NSTimeInterval)delay block:(void (^)(void))block;

/**
 * Dispatches after a delay, scheduled according to the provided timebase.
 * If the delay <= 0, the block will be dispatched asynchronously instead.
 *
 * @param delay The delay in seconds.
 * @param timebase The timebase.
 * @param block The block to dispatch.
 */
- (UADisposable *)dispatchAfter:(NSTimeInterval)delay timebase:(UADispatcherTimeBase)timebase block:(void (^)(void))block;

/**
 * Dispatches a block asynchronously.
 * @param block The block to dispatch.
 */
- (void)dispatchAsync:(void (^)(void))block;

/**
 * Dispatches a block synchronously.
 * @param block The block to dispatch.
 */
- (void)dispatchSync:(void (^)(void))block;

/**
 * Performs a block synchronously, either by dispatching onto
 * the associated queue or by runnning the block directly if
 * already on that queue.
 *
 * @param block The block to dispatch.
 */
- (void)doSync:(void (^)(void))block;

/**
 * Performs a block, either by dispatching onto
 * the associated queue asynchronously or by runnning the block directly if
 * already on that queue.
 *
 * @param block The block to dispatch.
 */
- (void)dispatchAsyncIfNecessary:(void (^)(void))block;

NS_ASSUME_NONNULL_END

@end
