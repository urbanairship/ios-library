/*
 Copyright 2009-2015 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Foundation/Foundation.h>

/**
 * Convenience interface for synchronizing tests across runloop iterations with dispatch semaphores.
 */
@interface UATestSynchronizer : NSObject


/**
 * The dispatch semaphore used for synchronization
 */
@property (nonatomic, strong) dispatch_semaphore_t semaphore;    // GCD objects use ARC

/**
 * How long the runloop should spin for each iteration while waiting.
 * Default is 0.1 seconds.
 */
@property (nonatomic, assign) NSTimeInterval runLoopInterval;
/**
 * How long to wait for a completion signal before timing out.
 * Default is 2 seconds.
 */
@property (nonatomic, assign) NSTimeInterval defaultTimeoutInterval;

/**
 * Spin the run loop iteratively until either a completion signal is delivered,
 * or the timeout is reached.
 *
 * @return `NO` if the timeout was reached, `YES` otherwise.
 */
- (BOOL)wait;

/**
 * Sping the run loop iteratively until either a completion signal is delivered,
 * or the timeout is reached.
 *
 * @param interval The desired timeout interval.
 * @return `NO` if the timeout was reached, `YES` otherwise.
 */
- (BOOL)waitWithTimeoutInterval:(NSTimeInterval)interval;

/**
 * Delivers a completion signal on the semaphore.
 */
- (void)continue;

@end
