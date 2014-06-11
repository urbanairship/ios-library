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
#import "UACustomEvent.h"
#import "UAAnalytics.h"
#import "UAirship.h"
#import <OCMock/OCMock.h>
#import "NSJSONSerialization+UAAdditions.h"

@interface UACustomEventTest : XCTestCase
@property(nonatomic, strong) id analytics;
@property(nonatomic, strong) id airship;

@end

@implementation UACustomEventTest

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
 * Test creating a custom event.
 */
- (void)testCustomEvent {
    NSString *eventName =  [@"" stringByPaddingToLength:255 withString:@"EVENT_NAME" startingAtIndex:0];
    NSString *transactionID =  [@"" stringByPaddingToLength:255 withString:@"TRANSACTION_ID" startingAtIndex:0];
    NSString *attributionID =  [@"" stringByPaddingToLength:255 withString:@"ATTRIBUTION_ID" startingAtIndex:0];
    NSString *attributionType =  [@"" stringByPaddingToLength:255 withString:@"ATTRIBUTION_TYPE" startingAtIndex:0];

    UACustomEvent *event = [UACustomEvent eventWithName:eventName value:@(INT32_MIN)];
    event.transactionID = transactionID;
    event.attributionID = attributionID;
    event.attributionType = attributionType;
    [event gatherData:@{}];

    XCTAssertEqualObjects(eventName, [event.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(transactionID, [event.data objectForKey:@"transaction_id"], @"Unexpected transaction id.");
    XCTAssertEqualObjects(attributionID, [event.data objectForKey:@"attribution_id"], @"Unexpected attribution id.");
    XCTAssertEqualObjects(attributionType, [event.data objectForKey:@"attribution_type"], @"Unexpected attribution type.");
    XCTAssertEqualObjects(@(INT32_MIN * 1000000.0), [event.data objectForKey:@"event_value"], @"Unexpected event value.");
}

/**
 * Test setting an event name.
 */
- (void)testSetCustomEventName {
    UACustomEvent *event = [UACustomEvent eventWithName:@"event name"];
    XCTAssertEqualObjects(event.eventName, @"event name", "255 character event name should be valid");

    event.eventName = nil;
    XCTAssertNil(event.eventName, @"Event names should be able to be cleared");


    event.eventName =  [@"" stringByPaddingToLength:256 withString:@"EVENT_NAME" startingAtIndex:0];
    XCTAssertNil(event.eventName, @"Event names larger than 255 characters should be ignored");

    NSString *eventName = [@"" stringByPaddingToLength:255 withString:@"EVENT_NAME" startingAtIndex:0];
    event.eventName =  eventName;
    XCTAssertEqualObjects(event.eventName, eventName, "255 character event name should be valid");
}

/**
 * Test setting the attribution ID.
 */
- (void)testSetAttributionID {
    UACustomEvent *event = [UACustomEvent eventWithName:@"event name"];
    XCTAssertNil(event.attributionID, @"Attribution ID should default to nil");

    NSString *attributionID = [@"" stringByPaddingToLength:255 withString:@"ATTRIBUTION_ID" startingAtIndex:0];

    event.attributionID = attributionID;
    XCTAssertEqualObjects(attributionID, event.attributionID, "255 character attribution IDs should be valid");

    event.attributionID = nil;
    XCTAssertNil(event.attributionID, @"Attribution ID should be able to be cleared");

    event.attributionID = [@"" stringByPaddingToLength:256 withString:@"ATTRIBUTION_ID" startingAtIndex:0];
    XCTAssertNil(event.attributionID, @"Attribution IDs larger than 255 characters should be ignored");
}

/**
 * Test setting the attribution type.
 */
- (void)testSetAttributionType {
    UACustomEvent *event = [UACustomEvent eventWithName:@"event name"];
    XCTAssertNil(event.attributionType, @"Attribution type should default to nil");

    NSString *attributionType = [@"" stringByPaddingToLength:255 withString:@"ATTRIBUTION_TYPE" startingAtIndex:0];

    event.attributionType = attributionType;
    XCTAssertEqualObjects(attributionType, event.attributionType, "255 character attribution Types should be valid");

    event.attributionType = nil;
    XCTAssertNil(event.attributionType, @"Attribution type should be able to be cleared");

    event.attributionType = [@"" stringByPaddingToLength:256 withString:@"ATTRIBUTION_TYPE" startingAtIndex:0];
    XCTAssertNil(event.attributionID, @"Attribution types larger than 255 characters should be ignored");
}

/**
 * Test setting the transaction ID
 */
- (void)testSetTransactionID {
    UACustomEvent *event = [UACustomEvent eventWithName:@"event name"];
    XCTAssertNil(event.transactionID, @"Transaction ID should default to nil");

    NSString *transactionID = [@"" stringByPaddingToLength:255 withString:@"TRANSACTION_ID" startingAtIndex:0];

    event.transactionID = transactionID;
    XCTAssertEqualObjects(transactionID, event.transactionID, "255 character transaction ID should be valid");

    event.transactionID = nil;
    XCTAssertNil(event.transactionID, @"Transaction ID should be able to be cleared");

    event.transactionID = [@"" stringByPaddingToLength:256 withString:@"TRANSACTION_ID" startingAtIndex:0];
    XCTAssertNil(event.attributionID, @"Transaction IDs larger than 255 characters should be ignored");
}

/**
 * Test event value from a string.
 */
- (void)testSetEventValueString {
    UACustomEvent *event = [UACustomEvent eventWithName:@"event name" valueFromString:@"100.00"];
    XCTAssertEqualObjects(@(100.00), event.eventValue, @"Event value should be set from a valid numeric string.");

    // Max value
    NSNumber *maxValue = @(INT32_MAX);
    event = [UACustomEvent eventWithName:@"event name" valueFromString:[maxValue stringValue]];
    XCTAssertEqualObjects(maxValue, event.eventValue, @"Event value should be set from a valid numeric string.");

    // Above Max
    NSDecimalNumber *aboveMax = [NSDecimalNumber decimalNumberWithDecimal:[maxValue decimalValue]];
    aboveMax = [aboveMax decimalNumberByAdding:[NSDecimalNumber decimalNumberWithString:@"0.000001"]];
    event = [UACustomEvent eventWithName:@"event name" valueFromString:[aboveMax stringValue]];
    XCTAssertNil(event.eventValue, @"Event values that are too large should be ignored.");

    // Min value
    NSNumber *minValue = @(INT32_MIN);
    event = [UACustomEvent eventWithName:@"event name" valueFromString:[minValue stringValue]];
    XCTAssertEqualObjects(minValue, event.eventValue, @"Event value should be set from a valid numeric string.");

    // Below min
    NSDecimalNumber *belowMin = [NSDecimalNumber decimalNumberWithDecimal:[minValue decimalValue]];
    belowMin = [belowMin decimalNumberBySubtracting:[NSDecimalNumber decimalNumberWithString:@"0.000001"]];
    event = [UACustomEvent eventWithName:@"event name" valueFromString:[belowMin stringValue]];
    XCTAssertNil(event.eventValue, @"Event values that are too small should be ignored.");

    // 0
    event = [UACustomEvent eventWithName:@"event name" valueFromString:@"0"];
    XCTAssertEqualObjects(@(0), event.eventValue, @"Event value should be set from a valid numeric string.");
}

/**
 * Test event value from an NSNumber.
 */
- (void)testSetEventValueNSNumber {
    UACustomEvent *event = [UACustomEvent eventWithName:@"event name" value:@(100)];
    XCTAssertEqualObjects(@(100.00), event.eventValue, @"Event value should be set from a valid numeric string.");

    // Max value
    NSNumber *maxValue = @(INT32_MAX);
    event = [UACustomEvent eventWithName:@"event name" value:maxValue];
    XCTAssertEqualObjects(maxValue, event.eventValue, @"Event value should be set from a valid numeric string.");

    // Above Max
    NSDecimalNumber *aboveMax = [NSDecimalNumber decimalNumberWithDecimal:[maxValue decimalValue]];
    aboveMax = [aboveMax decimalNumberByAdding:[NSDecimalNumber decimalNumberWithString:@"0.000001"]];
    event = [UACustomEvent eventWithName:@"event name" value:aboveMax];
    XCTAssertNil(event.eventValue, @"Event values that are too large should be ignored.");

    // Min value
    NSNumber *minValue = @(INT32_MIN);
    event = [UACustomEvent eventWithName:@"event name" value:minValue];
    XCTAssertEqualObjects(minValue, event.eventValue, @"Event value should be set from a valid numeric string.");

    // Below min
    NSDecimalNumber *belowMin = [NSDecimalNumber decimalNumberWithDecimal:[minValue decimalValue]];
    belowMin = [belowMin decimalNumberBySubtracting:[NSDecimalNumber decimalNumberWithString:@"0.000001"]];
    event = [UACustomEvent eventWithName:@"event name" value:belowMin];
    XCTAssertNil(event.eventValue, @"Event values that are too small should be ignored.");

    // 0
    event = [UACustomEvent eventWithName:@"event name" value:@(0)];
    XCTAssertEqualObjects(@(0), event.eventValue, @"Event value should be set from a valid numeric string.");
}


/**
 * Test event value to data conversion.  The value should be a decimal multiplied by
 * 10^6 and cast to a long.
 */
- (void)testEventValueToData {
    UACustomEvent *event = [UACustomEvent eventWithName:@"event name" value:@(123.123456789)];
    [event gatherData:@{}];
    XCTAssertEqualObjects(@(123123456), [event.data objectForKey:@"event_value"], @"Unexpected event value.");
}

/**
 * Test auto filling in the attribution if a hard conversion ID is set and neither
 * the attribution type or id is filled in.
 */
- (void)testAutoAttribution {
    UACustomEvent *event = [UACustomEvent eventWithName:@"event name" value:@(123.123456789)];
    [event gatherData:@{}];

    // Verify attribution is blank when conversion ID is nil
    XCTAssertNil([event.data objectForKey:@"attribution_id"], @"Attribution should be nil");
    XCTAssertNil([event.data objectForKey:@"attribution_type"], @"Attribution should be nil");

    // Set a conversion push ID for the analytics session
    [[[self.analytics stub] andReturn:@{@"launched_from_push_id":@"push ID"}] session];

    // Recreate the event to verify auto fil behavior
    event = [UACustomEvent eventWithName:@"event name" value:@(123.123456789)];
    [event gatherData:@{}];

    // Verify the attribution is hard open with the push ID
    XCTAssertEqualObjects(kUAAttributionHardOpen, [event.data objectForKey:@"attribution_type"], @"Attribution should autofil to hard open");
    XCTAssertEqualObjects(@"push ID", [event.data objectForKey:@"attribution_id"], @"Attribution should autofil to push id");

    // Recreate the event with a attribution ID to verify attribution does not auto fil
    event = [UACustomEvent eventWithName:@"event name" value:@(123.123456789)];
    event.attributionID = @"attribution ID";
    [event gatherData:@{}];

    XCTAssertEqualObjects(@"attribution ID", [event.data objectForKey:@"attribution_id"], @"Attribution ID should be the set value");
    XCTAssertNil([event.data objectForKey:@"attribution_type"], @"Attribution type is not set and should be nil");

    // Recreate the event with a attribution type to verify attribution does not auto fil
    event = [UACustomEvent eventWithName:@"event name" value:@(123.123456789)];
    event.attributionType = @"attribution type";
    [event gatherData:@{}];

    XCTAssertEqualObjects(@"attribution type", [event.data objectForKey:@"attribution_type"], @"Attribution type should be the set value");
    XCTAssertNil([event.data objectForKey:@"attribution_id"], @"Attribution ID is not set and should be nil");
}

/**
 * Test event is valid only when it has a set event name.
 */
- (void)testIsValid {
    UACustomEvent *event = [UACustomEvent eventWithName:@"event name" value:nil];
    XCTAssertTrue([event isValid], @"Event has a valid event name");

    event.eventName = nil;
    XCTAssertFalse([event isValid], @"Event should be invalid when it does not have an event name");

    event.eventName = @"";
    XCTAssertFalse([event isValid], @"Event should be invalid when it does not have an event name");
}



@end

