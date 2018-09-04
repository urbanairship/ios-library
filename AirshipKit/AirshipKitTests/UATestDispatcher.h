/* Copyright 2018 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UADispatcher+Internal.h"

/**
 * Test dispatcher.
 * All blocks dispatched async or sync will be run immediately inline. Any
 * blocks that are dispatched after a delay will only be exectued after
 * advancing the dispatcher time.
 */
@interface UATestDispatcher : UADispatcher

/**
 * Factory method to create the test dispatcher.
 * @returns A test dispatcher instance.
 */
+ (instancetype)testDispatcher;

/**
 * Run all blocks that are scheduled to run in the next time interval.
 *
 * @param time The amount of time to advance the dispatcher.
 */
- (void)advanceTime:(NSTimeInterval)time;

@end
