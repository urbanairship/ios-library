/*
 Copyright 2009-2014 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
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
#import "UA_Reachability.h"


@interface UAEventTest : XCTestCase

// stubs
@property(nonatomic, strong) id analytics;
@property(nonatomic, strong) id airship;
@property(nonatomic, strong) id reachability;
@property(nonatomic, strong) id timeZone;
@property(nonatomic, strong) id airshipVersion;
@property(nonatomic, strong) id application;

@end

@implementation UAEventTest

- (void)setUp {
    [super setUp];

    self.analytics = [OCMockObject niceMockForClass:[UAAnalytics class]];
    self.airship = [OCMockObject niceMockForClass:[UAirship class]];
    [[[self.airship stub] andReturn:self.airship] shared];
    [[[self.airship stub] andReturn:self.analytics] analytics];

    self.reachability = [OCMockObject niceMockForClass:[Reachability class]];
    [[[self.reachability stub] andReturn:self.reachability] reachabilityForInternetConnection];


    self.timeZone = [OCMockObject niceMockForClass:[NSTimeZone class]];
    [[[self.timeZone stub] andReturn:self.timeZone] defaultTimeZone];

    self.airshipVersion = [OCMockObject niceMockForClass:[UAirshipVersion class]];

    self.application = [OCMockObject niceMockForClass:[UIApplication class]];
    [[[self.application stub] andReturn:self.application] sharedApplication];
    
}

- (void)tearDown {
    [self.analytics stopMocking];
    [self.airship stopMocking];
    [self.reachability stopMocking];
    [self.timeZone stopMocking];
    [self.airshipVersion stopMocking];
    [self.application stopMocking];

    [super tearDown];
}

/**
 * Test app init event
 */
- (void)testAppInitEvent {
    [UAUser defaultUser].username = @"user id";
    [[[self.reachability stub] andReturnValue:@(UA_ReachableViaWWAN)] currentReachabilityStatus];
    [[[self.analytics stub] andReturn:@"push id"] conversionPushId];
    [[[self.analytics stub] andReturn:@"rich push id"] conversionRichPushId];

    [[[self.timeZone stub] andReturnValue:OCMOCK_VALUE((NSInteger)2000)] secondsFromGMT];
    [[[self.timeZone stub] andReturnValue:@YES] isDaylightSavingTime];

    [[[self.airship stub] andReturn:@"os version"] osVersion];
    [[[self.airship stub] andReturn:@"package version"] packageVersion];

    [[[self.airshipVersion stub] andReturn:@"airship version"] get];

    [[[self.application stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateActive)] applicationState];


    // Same as app init but without the foreground key
    NSDictionary *expectedData = @{@"user_id": @"user id",
                                   @"connection_type": @"cell",
                                   @"push_id": @"push id",
                                   @"rich_push_id": @"rich push id",
                                   @"time_zone": @2000,
                                   @"daylight_savings": @"true",
                                   @"notification_types": @[],
                                   @"os_version": @"os version",
                                   @"lib_version": @"airship version",
                                   @"package_version": @"package version",
                                   @"foreground": @"true"};


    UAEventAppInit *event = [UAEventAppInit event];
    XCTAssertEqualObjects(event.data, expectedData, @"Event data is unexpected.");
    XCTAssertEqualObjects(event.eventType, @"app_init", @"Event type is unexpected.");
    XCTAssertEqual(event.estimatedSize, kEventAppInitSize, @"Event is reporting wrong estimated size.");
    XCTAssertNotNil(event.eventId, @"Event should have an ID");

}

/**
 * Test app foreground event
 */
- (void)testAppForegroundEvent {
    [UAUser defaultUser].username = @"user id";
    [[[self.reachability stub] andReturnValue:@(UA_ReachableViaWWAN)] currentReachabilityStatus];
    [[[self.analytics stub] andReturn:@"push id"] conversionPushId];
    [[[self.analytics stub] andReturn:@"rich push id"] conversionRichPushId];

    [[[self.timeZone stub] andReturnValue:OCMOCK_VALUE((NSInteger)2000)] secondsFromGMT];
    [[[self.timeZone stub] andReturnValue:@YES] isDaylightSavingTime];

    [[[self.airship stub] andReturn:@"os version"] osVersion];
    [[[self.airship stub] andReturn:@"package version"] packageVersion];

    [[[self.airshipVersion stub] andReturn:@"airship version"] get];

    // Same as app init but without the foreground key
    NSDictionary *expectedData = @{@"user_id": @"user id",
                                   @"connection_type": @"cell",
                                   @"push_id": @"push id",
                                   @"rich_push_id": @"rich push id",
                                   @"time_zone": @2000,
                                   @"daylight_savings": @"true",
                                   @"notification_types": @[],
                                   @"os_version": @"os version",
                                   @"lib_version": @"airship version",
                                   @"package_version": @"package version"};


    UAEventAppForeground *event = [UAEventAppForeground event];
    XCTAssertEqualObjects(event.data, expectedData, @"Event data is unexpected.");
    XCTAssertEqualObjects(event.eventType, @"app_foreground", @"Event type is unexpected.");
    XCTAssertEqual(event.estimatedSize, kEventAppInitSize, @"Event is reporting wrong estimated size.");
    XCTAssertNotNil(event.eventId, @"Event should have an ID");

}

/**
 * Test app exit event
 */
- (void)testAppExitEvent {

    [[[self.reachability stub] andReturnValue:@(UA_ReachableViaWWAN)] currentReachabilityStatus];
    [[[self.analytics stub] andReturn:@"push id"] conversionPushId];
    [[[self.analytics stub] andReturn:@"rich push id"] conversionRichPushId];

    NSDictionary *expectedData = @{@"connection_type": @"cell",
                                   @"push_id": @"push id",
                                   @"rich_push_id": @"rich push id"};

    UAEventAppExit *event = [UAEventAppExit event];
    XCTAssertEqualObjects(event.data, expectedData, @"Event data is unexpected.");
    XCTAssertEqualObjects(event.eventType, @"app_exit", @"Event type is unexpected.");
    XCTAssertEqual(event.estimatedSize, kEventAppExitSize, @"Event is reporting wrong estimated size.");
    XCTAssertNotNil(event.eventId, @"Event should have an ID");
}

/**
 * Test app background event
 */
- (void)UAEventAppBackground {
    NSDictionary *expectedData = @{@"class_name": @""};

    UAEventAppBackground *event = [UAEventAppBackground event];
    XCTAssertEqualObjects(event.data, expectedData, @"Event data is unexpected.");
    XCTAssertEqualObjects(event.eventType, @"app_background", @"Event type is unexpected.");
    XCTAssertEqual(event.estimatedSize, kEventAppExitSize, @"Event is reporting wrong estimated size.");
    XCTAssertNotNil(event.eventId, @"Event should have an ID");
}

/**
 * Test app active event
 */
- (void)testAppActiveEvent {
    NSDictionary *expectedData = @{@"class_name": @""};

    UAEventAppActive *event = [UAEventAppActive event];
    XCTAssertEqualObjects(event.data, expectedData, @"Event data is unexpected.");
    XCTAssertEqualObjects(event.eventType, @"activity_started", @"Event type is unexpected.");
    XCTAssertEqual(event.estimatedSize, kEventAppActiveSize, @"Event is reporting wrong estimated size.");
    XCTAssertNotNil(event.eventId, @"Event should have an ID");
}

/**
 * Test app inactive event
 */
- (void)testAppInactiveEvent {
    NSDictionary *expectedData = @{@"class_name": @""};

    UAEventAppInactive *event = [UAEventAppInactive event];
    XCTAssertEqualObjects(event.data, expectedData, @"Event data is unexpected.");
    XCTAssertEqualObjects(event.eventType, @"activity_stopped", @"Event type is unexpected.");
    XCTAssertEqual(event.estimatedSize, kEventAppInactiveSize, @"Event is reporting wrong estimated size.");
    XCTAssertNotNil(event.eventId, @"Event should have an ID");
}

/**
 * Test device registration event
 */
- (void)testRegistrationEvent {
    [UAPush shared].deviceToken = @"a12312ad";
    [UAPush shared].channelID = @"someChannelID";
    [UAUser defaultUser].username = @"someUserID";

    NSDictionary *expectedData = @{@"device_token": @"a12312ad",
                                   @"channel_id": @"someChannelID",
                                   @"user_id": @"someUserID"};

    UAEventDeviceRegistration *event = [UAEventDeviceRegistration event];
    XCTAssertEqualObjects(event.data, expectedData, @"Event data is unexpected.");
    XCTAssertEqualObjects(event.eventType, @"device_registration", @"Event type is unexpected.");
    XCTAssertEqual(event.estimatedSize, kEventDeviceRegistrationSize, @"Event is reporting wrong estimated size.");
    XCTAssertNotNil(event.eventId, @"Event should have an ID");
}


/**
 * Test push received event
 */
- (void)testPushReceivedEvent {
    id notification = @{ @"_": @"push id",
                         @"_uamid": @"rich push id" };


    NSDictionary *expectedData = @{@"rich_push_id": @"rich push id",
                                   @"push_id": @"push id"};

    UAEventPushReceived *event = [UAEventPushReceived eventWithNotification:notification];
    XCTAssertEqualObjects(event.data, expectedData, @"Event data is unexpected.");
    XCTAssertEqualObjects(event.eventType, @"push_received", @"Event type is unexpected.");
    XCTAssertEqual(event.estimatedSize, kEventPushReceivedSize, @"Event is reporting wrong estimated size.");
    XCTAssertNotNil(event.eventId, @"Event should have an ID");
}

@end
