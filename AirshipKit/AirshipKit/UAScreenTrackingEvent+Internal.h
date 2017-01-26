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

#define kUAScreenTrackingEventType @"screen_tracking"

#define kUAScreenTrackingEventMaxCharacters 255
#define kUAScreenTrackingEventMinCharacters 1

#define kUAScreenTrackingEventScreenKey @"screen"
#define kUAScreenTrackingEventPreviousScreenKey @"previous_screen"
#define kUAScreenTrackingEventEnteredTimeKey @"entered_time"
#define kUAScreenTrackingEventExitedTimeKey @"exited_time"
#define kUAScreenTrackingEventDurationKey @"duration"


@interface UAScreenTrackingEvent : UAEvent

/**
 * The tracking event start time
 */
@property (nonatomic, assign) NSTimeInterval startTime;

/**
 * The tracking event stop time
 */
@property (nonatomic, assign) NSTimeInterval stopTime;

/**
 * The tracking event duration
 */
@property (nonatomic, assign) NSTimeInterval duration;

/**
 * The name of the screen to be tracked
 */
@property (nonatomic, copy, nonnull) NSString *screen;

/**
 * The name of the previous tracked screen
 */
@property (nonatomic, copy, nullable) NSString *previousScreen;

/**
 * Factory method to create a UAScreenTrackingEvent with screen name and startTime
 */
+ (nullable instancetype)eventWithScreen:(nonnull NSString *)screen startTime:(NSTimeInterval)startTime;

@end
