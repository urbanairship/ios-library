/* Copyright Urban Airship and Contributors */


#import <Foundation/Foundation.h>
#import "UADisposable.h"

/**
 * Class that wraps commmon GCD calls.
 */
@interface UADispatcher : NSObject

NS_ASSUME_NONNULL_BEGIN

/**
 * Shared dispatcher that dispatches on the main queue.
 * @return The shared main dispatcher.
 */
+ (instancetype)mainDispatcher;

/**
 * Shared dispatcher that dispatches on the background queue.
 * @return The shared background dispatcher.
 */
+ (instancetype)backgroundDispatcher;

/**
 * Dispatches after a delay. If the delay <= 0, the block will
 * be dispatched asynchronously instead.
 *
 * @param delay The delay in seconds.
 * @param block The block to dispatch.
 */
- (UADisposable *)dispatchAfter:(NSTimeInterval)delay block:(void (^)(void))block;

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
