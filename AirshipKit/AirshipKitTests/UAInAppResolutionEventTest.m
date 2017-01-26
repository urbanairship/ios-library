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
#import <OCMOCK/OCMock.h>
#import "UAAnalytics.h"
#import "UAirship.h"
#import "UAInAppResolutionEvent+Internal.h"
#import "UAInAppMessage.h"
#import "UAUtils.h"

@interface UAInAppResolutionEventTest : XCTestCase
@property (nonatomic, strong) id analytics;
@property (nonatomic, strong) id airship;
@property (nonatomic, strong) UAInAppMessage *message;
@end

@implementation UAInAppResolutionEventTest

- (void)setUp {
    [super setUp];

    self.analytics = [OCMockObject niceMockForClass:[UAAnalytics class]];
    self.airship = [OCMockObject niceMockForClass:[UAirship class]];

    [[[self.airship stub] andReturn:self.airship] shared];
    [[[self.airship stub] andReturn:self.analytics] analytics];

    self.message = [[UAInAppMessage alloc] init];
    self.message.identifier = [NSUUID UUID].UUIDString;
}

- (void)tearDown {
    [self.analytics stopMocking];
    [self.airship stopMocking];
    [super tearDown];
}

/**
 * Test in-app expired resolution event.
 */
- (void)testExpiredResolutionEvent {
    self.message.expiry = [NSDate date];
    [[[self.analytics stub] andReturn:[NSUUID UUID].UUIDString] conversionSendID];
    [[[self.analytics stub] andReturn:[NSUUID UUID].UUIDString] conversionPushMetadata];

    NSDateFormatter *formatter = [UAUtils ISODateFormatterUTCWithDelimiter];


    NSDictionary *expectedResolution = @{ @"type": @"expired",
                                          @"expiry": [formatter stringFromDate:self.message.expiry] };

    NSDictionary *expectedData = @{ @"id": self.message.identifier,
                                    @"conversion_send_id": [self.analytics conversionSendID],
                                    @"conversion_metadata": [self.analytics conversionPushMetadata],
                                    @"resolution": expectedResolution };


    UAInAppResolutionEvent *event = [UAInAppResolutionEvent expiredMessageResolutionWithMessage:self.message];
    [self verifyEvent:event expectedData:expectedData];
}

/**
 * Test in-app replaced resolution event.
 */
- (void)testReplacedResolutionEvent {
    UAInAppMessage *replacement = [[UAInAppMessage alloc] init];
    replacement.identifier = [NSUUID UUID].UUIDString;

    [[[self.analytics stub] andReturn:[NSUUID UUID].UUIDString] conversionSendID];
    [[[self.analytics stub] andReturn:[NSUUID UUID].UUIDString] conversionPushMetadata];


    NSDictionary *expectedResolution = @{ @"type": @"replaced",
                                          @"replacement_id": replacement.identifier };

    NSDictionary *expectedData = @{ @"id": self.message.identifier,
                                    @"conversion_send_id": [self.analytics conversionSendID],
                                    @"conversion_metadata": [self.analytics conversionPushMetadata],
                                    @"resolution": expectedResolution };


    UAInAppResolutionEvent *event = [UAInAppResolutionEvent replacedResolutionWithMessage:self.message
                                                                              replacement:replacement];

    [self verifyEvent:event expectedData:expectedData];
}

/**
 * Test in-app button clicked resolution event.
 */
- (void)testButtonClickedResolutionEvent {
    self.message.buttonGroup = @"button group";

    [[[self.analytics stub] andReturn:[NSUUID UUID].UUIDString] conversionSendID];
    [[[self.analytics stub] andReturn:[NSUUID UUID].UUIDString] conversionPushMetadata];


    NSDictionary *expectedResolution = @{ @"type": @"button_click",
                                          @"button_id": @"button ID",
                                          @"button_description": @"oh hi, marc",
                                          @"button_group": @"button group",
                                          @"display_time": @"3.141"};

    NSDictionary *expectedData = @{ @"id": self.message.identifier,
                                    @"conversion_send_id": [self.analytics conversionSendID],
                                    @"conversion_metadata": [self.analytics conversionPushMetadata],
                                    @"resolution": expectedResolution };


    UAInAppResolutionEvent *event = [UAInAppResolutionEvent buttonClickedResolutionWithMessage:self.message
                                                                              buttonIdentifier:@"button ID"
                                                                                   buttonTitle:@"oh hi, marc"
                                                                               displayDuration:3.141];

    [self verifyEvent:event expectedData:expectedData];
}


/**
 * Test in-app message clicked resolution event.
 */
- (void)testMessageClickedResolutionEvent {
    [[[self.analytics stub] andReturn:[NSUUID UUID].UUIDString] conversionSendID];
    [[[self.analytics stub] andReturn:[NSUUID UUID].UUIDString] conversionPushMetadata];


    NSDictionary *expectedResolution = @{ @"type": @"message_click",
                                          @"display_time": @"3.141"};

    NSDictionary *expectedData = @{ @"id": self.message.identifier,
                                    @"conversion_send_id": [self.analytics conversionSendID],
                                    @"conversion_metadata": [self.analytics conversionPushMetadata],
                                    @"resolution": expectedResolution };


    UAInAppResolutionEvent *event = [UAInAppResolutionEvent messageClickedResolutionWithMessage:self.message
                                                                                displayDuration:3.141];

    [self verifyEvent:event expectedData:expectedData];
}

/**
 * Test in-app dismisssed resolution event.
 */
- (void)testDismissedResolutionEvent {
    [[[self.analytics stub] andReturn:[NSUUID UUID].UUIDString] conversionSendID];
    [[[self.analytics stub] andReturn:[NSUUID UUID].UUIDString] conversionPushMetadata];


    NSDictionary *expectedResolution = @{ @"type": @"user_dismissed",
                                          @"display_time": @"3.141"};

    NSDictionary *expectedData = @{ @"id": self.message.identifier,
                                    @"conversion_send_id": [self.analytics conversionSendID],
                                    @"conversion_metadata": [self.analytics conversionPushMetadata],
                                    @"resolution": expectedResolution };


    UAInAppResolutionEvent *event = [UAInAppResolutionEvent dismissedResolutionWithMessage:self.message
                                                                           displayDuration:3.141];

    [self verifyEvent:event expectedData:expectedData];
}

/**
 * Test in-app timed out resolution event.
 */
- (void)testTimedOutResolutionEvent {
    [[[self.analytics stub] andReturn:[NSUUID UUID].UUIDString] conversionSendID];
    [[[self.analytics stub] andReturn:[NSUUID UUID].UUIDString] conversionPushMetadata];



    NSDictionary *expectedResolution = @{ @"type": @"timed_out",
                                          @"display_time": @"3.141"};

    NSDictionary *expectedData = @{ @"id": self.message.identifier,
                                    @"conversion_send_id": [self.analytics conversionSendID],
                                    @"conversion_metadata": [self.analytics conversionPushMetadata],
                                    @"resolution": expectedResolution };


    UAInAppResolutionEvent *event = [UAInAppResolutionEvent timedOutResolutionWithMessage:self.message
                                                                          displayDuration:3.141];

    [self verifyEvent:event expectedData:expectedData];
}

/**
 * Test in-app direct open resolution event.
 */
- (void)testDirectOpenResolutionEvent {
    [[[self.analytics stub] andReturn:[NSUUID UUID].UUIDString] conversionSendID];
    [[[self.analytics stub] andReturn:[NSUUID UUID].UUIDString] conversionPushMetadata];

    NSDictionary *expectedResolution = @{ @"type": @"direct_open" };

    NSDictionary *expectedData = @{ @"id": self.message.identifier,
                                    @"conversion_send_id": [self.analytics conversionSendID],
                                    @"conversion_metadata": [self.analytics conversionPushMetadata],
                                    @"resolution": expectedResolution };


    UAInAppResolutionEvent *event = [UAInAppResolutionEvent directOpenResolutionWithMessage:self.message];

    [self verifyEvent:event expectedData:expectedData];
}


- (void)verifyEvent:(UAInAppResolutionEvent *)event expectedData:(NSDictionary *)expectedData {
    XCTAssertEqualObjects(event.data, expectedData, @"Event data is unexpected.");
    XCTAssertEqualObjects(event.eventType, @"in_app_resolution", @"Event type is unexpected.");
    XCTAssertNotNil(event.eventID, @"Event should have an ID");
    XCTAssertTrue([event isValid], @"Event should be valid if it has a in-app message ID.");
}

@end
