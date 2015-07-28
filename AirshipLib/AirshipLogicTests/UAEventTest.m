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

#import <XCTest/XCTest.h>
#import <OCMOCK/OCMock.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>

#import "UAPush+Internal.h"
#import "UAUser+Internal.h"
#import "UAEvent.h"
#import "UAirship.h"
#import "UAAnalytics.h"
#import "UAEventAppInit.h"
#import "UAEventAppExit.h"
#import "UAEventAppBackground.h"
#import "UAEventAppForeground.h"
#import "UAEventDeviceRegistration.h"
#import "UAEventPushReceived.h"
#import "UAUtils.h"



@interface UAEventTest : XCTestCase

// stubs
@property (nonatomic, strong) id analytics;
@property (nonatomic, strong) id airship;
@property (nonatomic, strong) id reachability;
@property (nonatomic, strong) id timeZone;
@property (nonatomic, strong) id airshipVersion;
@property (nonatomic, strong) id application;
@property (nonatomic, strong) id push;
@property (nonatomic, strong) id currentDevice;
@property (nonatomic, strong) id user;
@property (nonatomic, strong) id utils;

@end

@implementation UAEventTest

- (void)setUp {
    [super setUp];

    self.analytics = [OCMockObject niceMockForClass:[UAAnalytics class]];
    self.push = [OCMockObject niceMockForClass:[UAPush class]];
    self.user = [OCMockObject niceMockForClass:[UAUser class]];

    self.airship = [OCMockObject niceMockForClass:[UAirship class]];

    [[[self.airship stub] andReturn:self.airship] shared];
    [[[self.airship stub] andReturn:self.analytics] analytics];
    [[[self.airship stub] andReturn:self.push] push];
    [[[self.airship stub] andReturn:self.user] inboxUser];

    self.utils = [OCMockObject niceMockForClass:[UAUtils class]];

    self.timeZone = [OCMockObject niceMockForClass:[NSTimeZone class]];
    [[[self.timeZone stub] andReturn:self.timeZone] defaultTimeZone];

    self.airshipVersion = [OCMockObject niceMockForClass:[UAirshipVersion class]];

    self.application = [OCMockObject niceMockForClass:[UIApplication class]];
    [[[self.application stub] andReturn:self.application] sharedApplication];

    self.currentDevice = [OCMockObject niceMockForClass:[UIDevice class]];
    [[[self.currentDevice stub] andReturn:self.currentDevice] currentDevice];
}

- (void)tearDown {
    [self.analytics stopMocking];
    [self.airship stopMocking];
    [self.timeZone stopMocking];
    [self.airshipVersion stopMocking];
    [self.application stopMocking];
    [self.push stopMocking];
    [self.currentDevice stopMocking];
    [self.utils stopMocking];

    [super tearDown];
}

/**
 * Test app init event
 */
- (void)testAppInitEvent {
    [[[self.user stub] andReturn:@"user ID"] username];

    [[[self.analytics stub] andReturn:@"push ID"] conversionSendID];
    [[[self.analytics stub] andReturn:@"rich push ID"] conversionRichPushID];

    [[[self.timeZone stub] andReturnValue:OCMOCK_VALUE((NSInteger)2000)] secondsFromGMT];

    [[[self.timeZone stub] andReturnValue:OCMOCK_VALUE(YES)] isDaylightSavingTime];

    [(UIDevice *)[[self.currentDevice stub] andReturn:@"os version"]systemVersion];

    [[[self.airshipVersion stub] andReturn:@"airship version"] get];

    [[[self.application stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateActive)] applicationState];

    [[[self.utils stub] andReturnValue:OCMOCK_VALUE(UAConnectionTypeCell)] connectionType];

    NSDictionary *expectedData = @{@"user_id": @"user ID",
                                   @"connection_type": @"cell",
                                   @"push_id": @"push ID",
                                   @"rich_push_id": @"rich push ID",
                                   @"time_zone": @2000,
                                   @"daylight_savings": @"true",
                                   @"notification_types": @[],
                                   @"os_version": @"os version",
                                   @"lib_version": @"airship version",
                                   @"package_version": @"",
                                   @"foreground": @"true"};


    UAEventAppInit *event = [UAEventAppInit event];

    XCTAssertEqualObjects(event.data, expectedData, @"Event data is unexpected.");
    XCTAssertEqualObjects(event.eventType, @"app_init", @"Event type is unexpected.");
    XCTAssertEqual(event.estimatedSize, kUAEventAppInitSize, @"Event is reporting wrong estimated size.");
    XCTAssertNotNil(event.eventID, @"Event should have an ID");

}

/**
 * Test app foreground event
 */
- (void)testAppForegroundEvent {
    [[[self.user stub] andReturn:@"user ID"] username];
    [[[self.analytics stub] andReturn:@"push ID"] conversionSendID];
    [[[self.analytics stub] andReturn:@"rich push ID"] conversionRichPushID];

    [[[self.timeZone stub] andReturnValue:OCMOCK_VALUE((NSInteger)2000)] secondsFromGMT];
    [[[self.timeZone stub] andReturnValue:OCMOCK_VALUE(YES)] isDaylightSavingTime];

    [[[self.utils stub] andReturnValue:OCMOCK_VALUE(UAConnectionTypeCell)] connectionType];

    [(UIDevice *)[[self.currentDevice stub] andReturn:@"os version"]systemVersion];

    [[[self.airshipVersion stub] andReturn:@"airship version"] get];

    // Same as app init but without the foreground key
    NSDictionary *expectedData = @{@"user_id": @"user ID",
                                   @"connection_type": @"cell",
                                   @"push_id": @"push ID",
                                   @"rich_push_id": @"rich push ID",
                                   @"time_zone": @2000,
                                   @"daylight_savings": @"true",
                                   @"notification_types": @[],
                                   @"os_version": @"os version",
                                   @"lib_version": @"airship version",
                                   @"package_version": @""};


    UAEventAppForeground *event = [UAEventAppForeground event];

    XCTAssertEqualObjects(event.data, expectedData, @"Event data is unexpected.");
    XCTAssertEqualObjects(event.eventType, @"app_foreground", @"Event type is unexpected.");
    XCTAssertEqual(event.estimatedSize, kUAEventAppInitSize, @"Event is reporting wrong estimated size.");
    XCTAssertNotNil(event.eventID, @"Event should have an ID");

}

/**
 * Test app exit event
 */
- (void)testAppExitEvent {

    [[[self.analytics stub] andReturn:@"push ID"] conversionSendID];
    [[[self.analytics stub] andReturn:@"rich push ID"] conversionRichPushID];

    [[[self.utils stub] andReturnValue:OCMOCK_VALUE(UAConnectionTypeCell)] connectionType];
    
    NSDictionary *expectedData = @{@"connection_type": @"cell",
                                   @"push_id": @"push ID",
                                   @"rich_push_id": @"rich push ID"};

    UAEventAppExit *event = [UAEventAppExit event];
    XCTAssertEqualObjects(event.data, expectedData, @"Event data is unexpected.");
    XCTAssertEqualObjects(event.eventType, @"app_exit", @"Event type is unexpected.");
    XCTAssertEqual(event.estimatedSize, kUAEventAppExitSize, @"Event is reporting wrong estimated size.");
    XCTAssertNotNil(event.eventID, @"Event should have an ID");
}

/**
 * Test app background event
 */
- (void)UAEventAppBackground {
    NSDictionary *expectedData = @{@"class_name": @""};

    UAEventAppBackground *event = [UAEventAppBackground event];
    XCTAssertEqualObjects(event.data, expectedData, @"Event data is unexpected.");
    XCTAssertEqualObjects(event.eventType, @"app_background", @"Event type is unexpected.");
    XCTAssertEqual(event.estimatedSize, kUAEventAppExitSize, @"Event is reporting wrong estimated size.");
    XCTAssertNotNil(event.eventID, @"Event should have an ID");
}

/**
 * Test device registration event
 */
- (void)testRegistrationEvent {
    [[[self.push stub] andReturn:@"a12312ad"] deviceToken];
    [[[self.push stub] andReturn:@"someChannelID"] channelID];
    [[[self.user stub] andReturn:@"someUserID"] username];

    NSDictionary *expectedData = @{@"device_token": @"a12312ad",
                                   @"channel_id": @"someChannelID",
                                   @"user_id": @"someUserID"};

    UAEventDeviceRegistration *event = [UAEventDeviceRegistration event];
    XCTAssertEqualObjects(event.data, expectedData, @"Event data is unexpected.");
    XCTAssertEqualObjects(event.eventType, @"device_registration", @"Event type is unexpected.");
    XCTAssertEqual(event.estimatedSize, kUAEventDeviceRegistrationSize, @"Event is reporting wrong estimated size.");
    XCTAssertNotNil(event.eventID, @"Event should have an ID");
}

/**
 * Test push received event
 */
- (void)testPushReceivedEvent {
    id notification = @{ @"_": @"push ID",
                         @"_uamid": @"rich push ID" };


    NSDictionary *expectedData = @{@"rich_push_id": @"rich push ID",
                                   @"push_id": @"push ID"};

    UAEventPushReceived *event = [UAEventPushReceived eventWithNotification:notification];
    XCTAssertEqualObjects(event.data, expectedData, @"Event data is unexpected.");
    XCTAssertEqualObjects(event.eventType, @"push_received", @"Event type is unexpected.");
    XCTAssertEqual(event.estimatedSize, kUAEventPushReceivedSize, @"Event is reporting wrong estimated size.");
    XCTAssertNotNil(event.eventID, @"Event should have an ID");
}

@end
