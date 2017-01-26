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
#import "UAScreenTrackingEvent+Internal.h"

@interface UAScreenTrackingEventTest : XCTestCase

@end

@implementation UAScreenTrackingEventTest

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

/**
 * Test event data directly.
 */
- (void)testScreenTrackingEventData {
    UAScreenTrackingEvent *event = [UAScreenTrackingEvent eventWithScreen:@"test_screen" startTime:0];
    event.stopTime = 1;
    event.previousScreen = @"previous_screen";

    NSDictionary *expectedData = @{
                                   @"duration":@"1.000",
                                   @"entered_time":@"0.000",
                                   @"exited_time":@"1.000",
                                   @"previous_screen":@"previous_screen",
                                   @"screen":@"test_screen",
                                   };

    XCTAssertEqualObjects(expectedData, event.data);
}

/**
 * Test validity of varying length screen names.
 */
- (void)testSetScreen {
    NSString *screenName = [@"" stringByPaddingToLength:255 withString:@"test_screen_name" startingAtIndex:0];

    UAScreenTrackingEvent *event = [UAScreenTrackingEvent eventWithScreen:screenName startTime:0];
    XCTAssertEqualObjects(event.screen, screenName);
    event.stopTime = 1;
    XCTAssertTrue(event.isValid);

    screenName = [@"" stringByPaddingToLength:256 withString:@"test_screen_name" startingAtIndex:0];
    event = [UAScreenTrackingEvent eventWithScreen:screenName startTime:0];
    XCTAssertEqualObjects(event.screen, screenName);
    event.stopTime = 1;
    XCTAssertFalse(event.isValid);

    screenName = @"";
    event = [UAScreenTrackingEvent eventWithScreen:screenName startTime:0];
    XCTAssertEqualObjects(event.screen, screenName);
    event.stopTime = 1;
    XCTAssertFalse(event.isValid);
}

/**
 * Test validity of screen tracking events with different stop times
 */
- (void)testSetStopTime {
    // Test invalid screen tracking event with no stop time
    UAScreenTrackingEvent *event = [UAScreenTrackingEvent eventWithScreen:@"test_screen" startTime:0];
    XCTAssertFalse(event.isValid);

    // Test invalid screen tracking event with stop time equal to start time
    event = [UAScreenTrackingEvent eventWithScreen:@"test_screen" startTime:0];
    event.stopTime = 0;
    XCTAssertFalse(event.isValid);

    // Test invalid screen tracking event with stop time before start time
    event = [UAScreenTrackingEvent eventWithScreen:@"test_screen" startTime:1];
    event.stopTime = 0;
    XCTAssertFalse(event.isValid);

    // Test valid screen tracking event with stop time after start time
    event = [UAScreenTrackingEvent eventWithScreen:@"test_screen" startTime:0];
    event.stopTime = 1;
    XCTAssertTrue(event.isValid);
}

@end
