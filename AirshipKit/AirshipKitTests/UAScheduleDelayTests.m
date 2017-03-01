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


#import <XCTest/XCTest.h>
#import "UAScheduleDelay.h"
#import "UAUtils.h"

@interface UAScheduleDelayTests : XCTestCase

@end

@implementation UAScheduleDelayTests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testWithJSON {
    NSDictionary *delayJson = @{ UAScheduleDelayRegionKey: @"test region",
                                 UAScheduleDelayScreenKey: @"test screen",
                                 UAScheduleDelaySecondsKey: @(100) };

    NSError *error = nil;
    UAScheduleDelay *delay = [UAScheduleDelay delayWithJSON:delayJson error:&error];

    XCTAssertEqualObjects(delay.screen, @"test screen");
    XCTAssertEqualObjects(delay.regionID, @"test region");
    XCTAssertEqual(delay.seconds, 100);
    XCTAssertEqual(delay.appState, UAScheduleDelayAppStateAny);

    XCTAssertNil(error);
}

- (void)testWithJsonBackgroundState {
    NSDictionary *delayJson = @{ UAScheduleDelayAppStateKey: UAScheduleTriggerAppBackgroundName };

    NSError *error = nil;
    UAScheduleDelay *delay = [UAScheduleDelay delayWithJSON:delayJson error:&error];

    XCTAssertEqual(delay.appState, UAScheduleDelayAppStateBackground);
    XCTAssertNil(error);
}

- (void)testWithJsonForegroundState {
    NSDictionary *delayJson = @{ UAScheduleDelayAppStateKey: UAScheduleTriggerAppForegroundName };

    NSError *error = nil;
    UAScheduleDelay *delay = [UAScheduleDelay delayWithJSON:delayJson error:&error];

    XCTAssertEqual(delay.appState, UAScheduleDelayAppStateForeground);
    XCTAssertNil(error);
}

- (void)testInvalidJSON {
    NSArray *invalidValues = @[
                               // Invalid seconds
                               @{UAScheduleDelaySecondsKey: @"one hundred" },

                               // Invalid screen
                               @{UAScheduleDelayScreenKey: @(1) },

                               //Invalid region
                               @{UAScheduleDelayRegionKey: @{} },

                               //Invalid app_state
                               @{UAScheduleDelayAppStateKey: @"invalid" },

                               // Invalid object
                               @"what" ];


    for (id value in invalidValues) {
        NSError *error;
        XCTAssertNil([UAScheduleDelay delayWithJSON:value error:&error]);
        XCTAssertNotNil(error);
    }
}


@end
