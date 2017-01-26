/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

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

#import "UAEvent.h"

/**
 * Represents the possible priorities for an event.
 */
typedef NS_ENUM(NSInteger, UAEventPriority) {
    /**
     * Low priority event. When added in the background, it will not schedule a send
     * if the last send was within 15 mins. Adding in the foreground will schedule
     * sends normally.
     */
    UAEventPriorityLow,

    /**
     * Normal priority event. Sends will be scheduled based on the batching time.
     */
    UAEventPriorityNormal,

    /**
     * High priority event. A send will be scheduled immediately.
     */
    UAEventPriorityHigh
};

NS_ASSUME_NONNULL_BEGIN

@interface UAEvent ()

/**
 * The time the event was created.
 */
@property (nonatomic, copy) NSString *time;

/**
 * The unique event ID.
 */
@property (nonatomic, copy) NSString *eventID;

/**
 * The event's data.
 */
@property (nonatomic, strong) NSDictionary *data;

/**
 * The event's priority.
 */
@property (nonatomic, readonly) UAEventPriority priority;

/**
 * The JSON event size in bytes.
 */
@property (nonatomic, readonly) NSUInteger jsonEventSize;

/**
 * Gets the carrier's name.
 * @returns The carrier's name.
 */
- (NSString *)carrierName;

/**
 * Gets the current enabled notification types as a string array.
 *
 * @return The current notification types as a string array.
 */
- (NSArray *)notificationTypes;


@end

NS_ASSUME_NONNULL_END
