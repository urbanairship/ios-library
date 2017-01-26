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
#import "UAAccountEventTemplate.h"
#import "UAAnalytics.h"
#import "UAirship.h"
#import "UACustomEvent.h"
#import <OCMock/OCMock.h>

@interface UAAccountEventTemplateTest : XCTestCase
@property (nonatomic, strong) id analytics;
@property (nonatomic, strong) id airship;
@end

@implementation UAAccountEventTemplateTest

- (void)setUp {
    self.analytics = [OCMockObject niceMockForClass:[UAAnalytics class]];
    self.airship = [OCMockObject mockForClass:[UAirship class]];
    [[[self.airship stub] andReturn:self.airship] shared];
    [[[self.airship stub] andReturn:self.analytics] analytics];

    [super setUp];
}

- (void)tearDown {
    [self.airship stopMocking];
    [self.analytics stopMocking];

    [super tearDown];
}

/**
 * Test basic account event with no optional value or properties.
 */
- (void)testBasicAccountEvent {
    UAAccountEventTemplate *event = [UAAccountEventTemplate registeredTemplate];
    UACustomEvent *customEvent = [event createEvent];

    XCTAssertEqualObjects(@"registered_account", [customEvent.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(@"false", customEvent.data[@"properties"][@"ltv"], @"Property ltv should be NO.");
    XCTAssertEqualObjects(@"account", [customEvent.data objectForKey:@"template_type"], @"Unexpected event template type.");
}

/**
 * Test account event with optional value from string.
 */
- (void)testAccountEventWithValueFromString {
    UAAccountEventTemplate *event = [UAAccountEventTemplate registeredTemplateWithValueFromString:@"100.00"];
    UACustomEvent *customEvent = [event createEvent];

    XCTAssertEqualObjects(@"registered_account", [customEvent.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(@(100.00), customEvent.eventValue, @"Event value should be set from a valid numeric string.");
    XCTAssertEqualObjects(@"true", customEvent.data[@"properties"][@"ltv"], @"Unexpected ltv property.");
    XCTAssertEqualObjects(@"account", [customEvent.data objectForKey:@"template_type"], @"Unexpected event template type.");
}

/**
 * Test account event with optional value.
 */
- (void)testAccountEventWithValue {
    UAAccountEventTemplate *event = [UAAccountEventTemplate registeredTemplateWithValue:@(INT32_MIN)];
    UACustomEvent *customEvent = [event createEvent];

    XCTAssertEqualObjects(@"registered_account", [customEvent.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(@(INT32_MIN * 1000000.0), [customEvent.data objectForKey:@"event_value"], @"Unexpected event value.");
    XCTAssertEqualObjects(@"true", customEvent.data[@"properties"][@"ltv"], @"Unexpected ltv property.");
    XCTAssertEqualObjects(@"account", [customEvent.data objectForKey:@"template_type"], @"Unexpected event template type.");
}

/**
 * Test account event with optional value and properties.
 */
- (void)testAccountEventWithValueProperties {
    UAAccountEventTemplate *eventTemplate = [UAAccountEventTemplate registeredTemplate];
    eventTemplate.eventValue = [NSDecimalNumber decimalNumberWithString:@"12345.00"];
    eventTemplate.transactionID = @"1212";
    eventTemplate.category = @"Premium";

    UACustomEvent *customEvent = [eventTemplate createEvent];
    [customEvent track];

    XCTAssertEqualObjects(@"registered_account", [customEvent.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(@(12345), customEvent.eventValue, @"Unexpected event value.");
    XCTAssertEqualObjects(@"true", customEvent.data[@"properties"][@"ltv"], @"Unexpected ltv property.");
    XCTAssertEqualObjects(@"1212", customEvent.transactionID, @"Unexpected transaction ID.");
    XCTAssertEqualObjects(@"\"Premium\"", customEvent.data[@"properties"][@"category"], @"Unexpected category.");
    XCTAssertEqualObjects(@"account", [customEvent.data objectForKey:@"template_type"], @"Unexpected event template type.");
}

@end
