/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Utility class that wraps a dispatch semaphore and related GCD calls.
 * @note For internal use only. :nodoc:
 */
@interface UASemaphore : NSObject

/**
 * UASemaphore class factory method.
 */
+ (instancetype)semaphore;

/**
 * Waits on the semaphore indefinitely.
 */
- (void)wait;

/**
 * Waits on the semaphore, timing out after the provided interval.
 *
 * @return `YES` if the wait completed normally, `NO` if the timeout was reached.
 */
- (BOOL)wait:(NSTimeInterval)timeout;

/**
 * Signals the semaphore.
 *
 * @return `YES` if the signal woke the waiting thread, `NO` otherwise.
 */
- (BOOL)signal;

@end

NS_ASSUME_NONNULL_END
