/*
 Copyright 2009-2016 Urban Airship Inc. All rights reserved.

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

#import "UAScreenTrackingEvent+Internal.h"
#import "UAEvent+Internal.h"
#import "UAGlobal.h"

@implementation UAScreenTrackingEvent

+ (instancetype)eventWithScreen:(NSString *)screen startTime:(NSTimeInterval)startTime {

    UAScreenTrackingEvent *screenTrackingEvent = [[UAScreenTrackingEvent alloc] init];
    screenTrackingEvent.screen = screen;
    screenTrackingEvent.startTime = startTime;

    return screenTrackingEvent;
}

- (BOOL)isValid {

    if (![UAScreenTrackingEvent screenTrackingEventCharacterCountIsValid:self.screen]) {
        UA_LERR(@"Screen name must not be greater than %d characters or less than %d characters in length.", kUAScreenTrackingEventMaxCharacters, kUAScreenTrackingEventMinCharacters);
        return NO;
    }

    // Return early if tracking duration is < 0
    if (self.duration <= 0) {
        UA_LERR(@"Screen tracking duration must be positive.");
        return NO;
    }

    return YES;
}

- (NSString *)eventType {
    return kUAScreenTrackingEventType;
}

- (NSTimeInterval)duration {

    if (!self.stopTime) {
        UA_LERR(@"Duration is not available without a stop time.");
        return 0;
    }

    return self.stopTime - self.startTime;
}

+ (BOOL)screenTrackingEventCharacterCountIsValid:(NSString *)string {
    if (!string || string.length > kUAScreenTrackingEventMaxCharacters || string.length < kUAScreenTrackingEventMinCharacters) {
        return NO;
    }

    return YES;
}

- (NSDictionary *)data {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

    [dictionary setValue:self.screen forKey:kUAScreenTrackingEventScreenKey];
    [dictionary setValue:self.previousScreen forKey:kUAScreenTrackingEventPreviousScreenKey];
    [dictionary setValue:[NSString stringWithFormat:@"%0.3f", self.startTime] forKey:kUAScreenTrackingEventEnteredTimeKey];
    [dictionary setValue:[NSString stringWithFormat:@"%0.3f", self.stopTime] forKey:kUAScreenTrackingEventExitedTimeKey];
    [dictionary setValue:[NSString stringWithFormat:@"%0.3f", self.duration] forKey:kUAScreenTrackingEventDurationKey];

    return dictionary;
}

@end
