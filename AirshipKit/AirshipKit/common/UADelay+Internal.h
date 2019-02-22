/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Util class around semaphore delays
 */
@interface UADelay : NSObject

/**
 * Cancels the delay.
 */
- (void)cancel;

/**
 * Starts the delay.
 */
- (void)start;

/**
 * Creates the delay.
 * @param seconds Delay in seconds.
 * @return The delay instance.
 */
+ (instancetype)delayWithSeconds:(NSTimeInterval)seconds;

/**
 * The amount of the the delay in seconds.
 */
@property (nonatomic, assign, readonly) NSTimeInterval seconds;


@end

NS_ASSUME_NONNULL_END
