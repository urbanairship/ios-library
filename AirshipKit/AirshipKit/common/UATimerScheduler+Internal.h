/* Copyright 2010-2019 Urban Airship and Contributors */

#import <Foundation/Foundation.h>

/**
 * Helper class for scheduling timers.
 */
@interface UATimerScheduler : NSObject

/**
 * Schedules a timer on the current run loop.
 *
 * @param timer A timer.
 */
- (void)scheduleTimer:(NSTimer *)timer;

@end
