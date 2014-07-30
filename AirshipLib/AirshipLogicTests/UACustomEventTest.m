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
    NSString *interactionID =  [@"" stringByPaddingToLength:255 withString:@"INTERACTION_ID" startingAtIndex:0];
    NSString *interactionType =  [@"" stringByPaddingToLength:255 withString:@"INTERACTION_TYPE" startingAtIndex:0];

    UACustomEvent *event = [UACustomEvent eventWithName:eventName value:@(INT32_MIN)];
    event.transactionID = transactionID;
    event.interactionID = interactionID;
    event.interactionType = interactionType;

    XCTAssertEqualObjects(eventName, [event.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(transactionID, [event.data objectForKey:@"transaction_id"], @"Unexpected transaction id.");
    XCTAssertEqualObjects(interactionID, [event.data objectForKey:@"interaction_id"], @"Unexpected interaction id.");
    XCTAssertEqualObjects(interactionType, [event.data objectForKey:@"interaction_type"], @"Unexpected interaction type.");
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
 * Test setting the interaction ID.
 */
- (void)testSetInteractionID {
    UACustomEvent *event = [UACustomEvent eventWithName:@"event name"];
    XCTAssertNil(event.interactionID, @"Interaction ID should default to nil");

    NSString *interactionID = [@"" stringByPaddingToLength:255 withString:@"INTERACTION_ID" startingAtIndex:0];

    event.interactionID = interactionID;
    XCTAssertEqualObjects(interactionID, event.interactionID, "255 character interaction IDs should be valid");

    event.interactionID = nil;
    XCTAssertNil(event.interactionID, @"Interaction ID should be able to be cleared");

    event.interactionID = [@"" stringByPaddingToLength:256 withString:@"INTERACTION_ID" startingAtIndex:0];
    XCTAssertNil(event.interactionID, @"Interaction IDs larger than 255 characters should be ignored");
}

/**
 * Test setting the interaction type.
 */
- (void)testSetInteractionType {
    UACustomEvent *event = [UACustomEvent eventWithName:@"event name"];
    XCTAssertNil(event.interactionType, @"Interaction type should default to nil");

    NSString *interactionType = [@"" stringByPaddingToLength:255 withString:@"INTERACTION_TYPE" startingAtIndex:0];

    event.interactionType = interactionType;
    XCTAssertEqualObjects(interactionType, event.interactionType, "255 character interaction Types should be valid");

    event.interactionType = nil;
    XCTAssertNil(event.interactionType, @"Interaction type should be able to be cleared");

    event.interactionType = [@"" stringByPaddingToLength:256 withString:@"INTERACTION_TYPE" startingAtIndex:0];
    XCTAssertNil(event.interactionType, @"Interaction types larger than 255 characters should be ignored");
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
    XCTAssertNil(event.transactionID, @"Transaction IDs larger than 255 characters should be ignored");
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

    // nil
    event = [UACustomEvent eventWithName:@"event name" valueFromString:nil];
    XCTAssertNil(event.eventValue, @"Event values that nil should be ignored.");

    // NaN
    event = [UACustomEvent eventWithName:@"event name" valueFromString:@"blah"];
    XCTAssertNil(event.eventValue, @"Event values that are not numbers should be ignored");
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

    // nil
    event = [UACustomEvent eventWithName:@"event name" value:nil];
    XCTAssertNil(event.eventValue, @"Nil event values should be ignored.");

    // NaN
    event = [UACustomEvent eventWithName:@"event name" value:[NSDecimalNumber notANumber]];
    XCTAssertNil(event.eventValue, @"NSDecimalNumbers that are equal to notANumber should be ignored.");
}


/**
 * Test event value to data conversion.  The value should be a decimal multiplied by
 * 10^6 and cast to a long.
 */
- (void)testEventValueToData {
    UACustomEvent *event = [UACustomEvent eventWithName:@"event name" value:@(123.123456789)];
    XCTAssertEqualObjects(@(123123456), [event.data objectForKey:@"event_value"], @"Unexpected event value.");
}

/**
 * Test event includes conversion send id if available.
 */
- (void)testConversionSendID {
    [[[self.analytics stub] andReturn:@"send ID"] conversionSendId];
    UACustomEvent *event = [UACustomEvent eventWithName:@"event name"];

    XCTAssertEqualObjects(@"send ID", [event.data objectForKey:@"conversion_send_id"], @"Send id should be set.");
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

