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
#import "UAInAppDisplayEvent+Internal.h"
#import "UAInAppMessage.h"

@interface UAInAppDisplayEventTest : XCTestCase
@property (nonatomic, strong) id analytics;
@property (nonatomic, strong) id airship;
@end

@implementation UAInAppDisplayEventTest

- (void)setUp {
    [super setUp];

    self.analytics = [OCMockObject niceMockForClass:[UAAnalytics class]];
    self.airship = [OCMockObject niceMockForClass:[UAirship class]];

    [[[self.airship stub] andReturn:self.airship] shared];
    [[[self.airship stub] andReturn:self.analytics] analytics];
}

- (void)tearDown {
    [self.analytics stopMocking];
    [self.airship stopMocking];
    [super tearDown];
}

/**
 * Test events data.
 */
- (void)testValidEvent {

    UAInAppMessage *message = [[UAInAppMessage alloc] init];
    message.identifier = [NSUUID UUID].UUIDString;
    [[[self.analytics stub] andReturn:[NSUUID UUID].UUIDString] conversionSendID];
    [[[self.analytics stub] andReturn:@"base64metadataString"] conversionPushMetadata];


    NSDictionary *expectedData = @{ @"id": message.identifier,
                                    @"conversion_send_id": [self.analytics conversionSendID],
                                    @"conversion_metadata": [self.analytics conversionPushMetadata]};



    UAInAppDisplayEvent *event = [UAInAppDisplayEvent eventWithMessage:message];
    XCTAssertEqualObjects(event.data, expectedData, @"Event data is unexpected.");
    XCTAssertEqualObjects(event.eventType, @"in_app_display", @"Event type is unexpected.");
    XCTAssertNotNil(event.eventID, @"Event should have an ID");
    XCTAssertTrue([event isValid], @"Event should be valid if it has a in-app message ID.");
}

/**
 * Test event is invalid if it is missing the in-app message ID.
 */
- (void)testInvalidData {
    UAInAppMessage *message = [[UAInAppMessage alloc] init];

    [[[self.analytics stub] andReturn:[NSUUID UUID].UUIDString] conversionSendID];

    UAInAppDisplayEvent *event = [UAInAppDisplayEvent eventWithMessage:message];
    XCTAssertFalse([event isValid], @"Event should be valid if it has a in-app message ID.");
}

@end
