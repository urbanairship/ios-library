/* Copyright 2018 Urban Airship and Contributors */


#import <Foundation/Foundation.h>

/**
 * Class that wraps commmon GCD calls.
 */
@interface UADispatcher : NSObject

NS_ASSUME_NONNULL_BEGIN

/**
 * Factory method.
 * @param queue The dispatcher's queue.
 * @return A UADispatcher instance.
 */
+ (instancetype)dispatcherWithQueue:(dispatch_queue_t)queue;

/**
 * Shared dispatcher that dispatches on the main queue.
 * @return The shared main dispatcher.
 */
+ (instancetype)mainDispatcher;

/**
 * Dispatches after a delay. If the delay <= 0, the block will
 * be dispatched asynchronously instead.
 *
 * @param delay The delay in seconds.
 * @param block The block to dispatch.
 */
- (void)dispatchAfter:(NSTimeInterval)delay block:(void (^)(void))block;

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

NS_ASSUME_NONNULL_END

@end
