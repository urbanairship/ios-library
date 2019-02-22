/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>

/**
 * Helper class for scheduling timers.
 */
@interface UATimerScheduler : NSObject

/**
 * Factory method.
 *
 * @return A new timer scheduler instance.
 */
+ (instancetype)timerScheduler;

/**
 * Factory method.
 *
 * @param schedulerBlock A block used to schedule timers.
 * @return A new timer scheduler instance.
 */
+ (instancetype)timerSchedulerWithSchedulerBlock:(void (^)(NSTimer *))schedulerBlock;

/**
 * Schedules a timer on the current run loop.
 *
 * @param timer A timer.
 */
- (void)scheduleTimer:(NSTimer *)timer;

@end
