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


@interface UAEventTest : XCTestCase
@property(nonatomic, strong) id analytics;
@property(nonatomic, strong) id airship;

@property(nonatomic, strong) NSMutableDictionary *session;
@end

@implementation UAEventTest

- (void)setUp {
    [super setUp];

    self.analytics = [OCMockObject niceMockForClass:[UAAnalytics class]];
    self.airship = [OCMockObject mockForClass:[UAirship class]];
    [[[self.airship stub] andReturn:self.airship] shared];
    [[[self.airship stub] andReturn:self.analytics] analytics];

    self.session = [NSMutableDictionary dictionary];
    [[[self.analytics stub] andReturn:self.session] session];
}

- (void)tearDown {
    [self.analytics stopMocking];
    [self.airship stopMocking];
    [super tearDown];
}

/**
 * Test app init event
 */
- (void)testAppInitEvent {
    [UAUser defaultUser].username = @"user id";

    [self.session setValue:@"connection type" forKey:@"connection_type"];
    [self.session setValue:@"push id" forKey:@"launched_from_push_id"];
    [self.session setValue:@"rich push id" forKey:@"launched_from_rich_push_id"];
    [self.session setValue:@"true" forKey:@"foreground"];
    [self.session setValue:@"time zone" forKey:@"time_zone"];
    [self.session setValue:@"daylight savings" forKey:@"daylight_savings"];
    [self.session setValue:@"notification types" forKey:@"notification_types"];
    [self.session setValue:@"os version" forKey:@"os_version"];
    [self.session setValue:@"package version" forKey:@"package_version"];
    [self.session setValue:@"lib version" forKey:@"lib_version"];
    [self.session setValue:@"some carrier" forKey:@"carrier"];

    NSDictionary *expectedData = @{@"user_id": @"user id",
                                   @"connection_type": @"connection type",
                                   @"push_id": @"push id",
                                   @"rich_push_id": @"rich push id",
                                   @"foreground": @"true",
                                   @"carrier": @"some carrier",
                                   @"time_zone": @"time zone",
                                   @"daylight_savings": @"daylight savings",
                                   @"daylight_savings": @"daylight savings",
                                   @"notification_types": @"notification types",
                                   @"os_version": @"os version",
                                   @"lib_version": @"lib version",
                                   @"package_version": @"package version"};


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

    [self.session setValue:@"connection type" forKey:@"connection_type"];
    [self.session setValue:@"push id" forKey:@"launched_from_push_id"];
    [self.session setValue:@"rich push id" forKey:@"launched_from_rich_push_id"];
    [self.session setValue:@"true" forKey:@"foreground"];
    [self.session setValue:@"time zone" forKey:@"time_zone"];
    [self.session setValue:@"daylight savings" forKey:@"daylight_savings"];
    [self.session setValue:@"notification types" forKey:@"notification_types"];
    [self.session setValue:@"os version" forKey:@"os_version"];
    [self.session setValue:@"package version" forKey:@"package_version"];
    [self.session setValue:@"lib version" forKey:@"lib_version"];
    [self.session setValue:@"some carrier" forKey:@"carrier"];

    // Same as app init but without the foreground key
    NSDictionary *expectedData = @{@"user_id": @"user id",
                                   @"connection_type": @"connection type",
                                   @"push_id": @"push id",
                                   @"rich_push_id": @"rich push id",
                                   @"carrier": @"some carrier",
                                   @"time_zone": @"time zone",
                                   @"daylight_savings": @"daylight savings",
                                   @"daylight_savings": @"daylight savings",
                                   @"notification_types": @"notification types",
                                   @"os_version": @"os version",
                                   @"lib_version": @"lib version",
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
    [self.session setValue:@"connection type" forKey:@"connection_type"];
    [self.session setValue:@"push id" forKey:@"launched_from_push_id"];
    [self.session setValue:@"rich push id" forKey:@"launched_from_rich_push_id"];

    NSDictionary *expectedData = @{@"connection_type": @"connection type",
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
    XCTAssertEqual(event.estimatedSize, kEventAppActiveSize, @"Event is reporting wrong estimated size.");
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
