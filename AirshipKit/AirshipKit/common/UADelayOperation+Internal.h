/* Copyright Urban Airship and Contributors */

#import "UADelay+Internal.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * An NSOperation that sleeps for a specified number of seconds before completing.
 *
 * This class is useful for scheduling delayed work or retry logic in an NSOperationQueue.
 */
@interface UADelayOperation : NSBlockOperation

/**
 * UADelayOperation class factory method.
 * @param seconds The number of seconds to sleep.
 * @return The delay operation.
 */
+ (instancetype)operationWithDelayInSeconds:(NSTimeInterval)seconds;

/**
 * UADelayOperation class factory method.
 * @param delay The delay.
 * @return The delay operation.
 */
+ (instancetype)operationWithDelay:(UADelay *)delay;

/**
 * The amount of the the delay in seconds.
 */
@property (nonatomic, assign, readonly) NSTimeInterval seconds;

@end

NS_ASSUME_NONNULL_END
