/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "NSJSONSerialization+UAAdditions.h"
#import "AirshipTests-Swift.h"

@import AirshipCore;

@interface UACustomEventTest : UABaseTest
@property(nonatomic, strong) UATestAnalytics *analytics;
@property(nonatomic, strong) UATestAirshipInstance *airship;
@end

@implementation UACustomEventTest

- (void)setUp {
    [super setUp];

    self.analytics = [[UATestAnalytics alloc] init];
    self.airship = [[UATestAirshipInstance alloc] init];
    self.airship.components = @[self.analytics];
    [self.airship makeShared];
}

/**
 * Test creating a custom event.
 */
- (void)testCustomEvent {
    NSString *eventName =  [@"" stringByPaddingToLength:255 withString:@"EVENT_NAME" startingAtIndex:0];
    NSString *transactionID =  [@"" stringByPaddingToLength:255 withString:@"TRANSACTION_ID" startingAtIndex:0];
    NSString *interactionID =  [@"" stringByPaddingToLength:255 withString:@"INTERACTION_ID" startingAtIndex:0];
    NSString *interactionType =  [@"" stringByPaddingToLength:255 withString:@"INTERACTION_TYPE" startingAtIndex:0];
    NSString *templateType =  [@"" stringByPaddingToLength:255 withString:@"TEMPLATE_TYPE" startingAtIndex:0];

    UACustomEvent *event = [UACustomEvent eventWithName:eventName value:@(INT32_MIN)];
    event.transactionID = transactionID;
    event.interactionID = interactionID;
    event.interactionType = interactionType;
    event.templateType = templateType;

    XCTAssertEqualObjects(eventName, [event.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(transactionID, [event.data objectForKey:@"transaction_id"], @"Unexpected transaction ID.");
    XCTAssertEqualObjects(interactionID, [event.data objectForKey:@"interaction_id"], @"Unexpected interaction ID.");
    XCTAssertEqualObjects(interactionType, [event.data objectForKey:@"interaction_type"], @"Unexpected interaction type.");
    XCTAssertEqualObjects(templateType, [event.data objectForKey:@"template_type"], @"Unexpected template type.");
    XCTAssertEqualObjects(@(INT32_MIN * 1000000.0), [event.data objectForKey:@"event_value"], @"Unexpected event value.");
}

/**
 * Test setting an event name.
 */
- (void)testSetCustomEventName {
    UACustomEvent *event = [UACustomEvent eventWithName:@"event name"];
    XCTAssertTrue(event.isValid);

    NSString *eventName = [@"" stringByPaddingToLength:255 withString:@"EVENT_NAME" startingAtIndex:0];
    event.eventName =  eventName;
    XCTAssertTrue(event.isValid);
}

/**
 * Test setting the interaction ID.
 */
- (void)testSetInteractionID {
    UACustomEvent *event = [UACustomEvent eventWithName:@"event name"];
    XCTAssertNil(event.interactionID, @"Interaction ID should default to nil");

    NSString *interactionID = [@"" stringByPaddingToLength:255 withString:@"INTERACTION_ID" startingAtIndex:0];

    event.interactionID = interactionID;
    XCTAssertTrue(event.isValid);

    event.interactionID = nil;
    XCTAssertTrue(event.isValid);
}

/**
 * Test setting the interaction type.
 */
- (void)testSetInteractionType {
    UACustomEvent *event = [UACustomEvent eventWithName:@"event name"];
    XCTAssertNil(event.interactionType, @"Interaction type should default to nil");

    NSString *interactionType = [@"" stringByPaddingToLength:255 withString:@"INTERACTION_TYPE" startingAtIndex:0];

    event.interactionType = interactionType;
    XCTAssertTrue(event.isValid);

    event.interactionType = nil;
    XCTAssertTrue(event.isValid);
}

/**
 * Test setting the transaction ID
 */
- (void)testSetTransactionID {
    UACustomEvent *event = [UACustomEvent eventWithName:@"event name"];
    XCTAssertNil(event.transactionID, @"Transaction ID should default to nil");

    NSString *transactionID = [@"" stringByPaddingToLength:255 withString:@"TRANSACTION_ID" startingAtIndex:0];

    event.transactionID = transactionID;
    XCTAssertTrue(event.isValid);

    event.transactionID = nil;
    XCTAssertTrue(event.isValid);
}

/**
 * Test set template type
 */
- (void)testSetTemplateType {
    UACustomEvent *event = [UACustomEvent eventWithName:@"some event"];
    XCTAssertNil(event.templateType, @"Template type should default to nil");

    NSString *templateType = [@"" stringByPaddingToLength:255 withString:@"TEMPLATE_TYPE" startingAtIndex:0];

    event.templateType = templateType;
    XCTAssertTrue(event.isValid);

    event.templateType = nil;
    XCTAssertTrue(event.isValid);
}

/**
 * Test event value from a string.
 */
- (void)testSetEventValueString {
    UACustomEvent *event = [UACustomEvent eventWithName:@"event name" valueFromString:@"100.00"];
    XCTAssertEqualObjects(@(100.00), event.eventValue, @"Event value should be set from a valid numeric string.");
    XCTAssertTrue(event.isValid);

    // Max value
    NSNumber *maxValue = @(INT32_MAX);
    event = [UACustomEvent eventWithName:@"event name" valueFromString:[maxValue stringValue]];
    XCTAssertEqualObjects(maxValue, event.eventValue, @"Event value should be set from a valid numeric string.");
    XCTAssertTrue(event.isValid);

    // Above Max
    NSDecimalNumber *aboveMax = [NSDecimalNumber decimalNumberWithDecimal:[maxValue decimalValue]];
    aboveMax = [aboveMax decimalNumberByAdding:[NSDecimalNumber decimalNumberWithString:@"0.000001"]];
    event = [UACustomEvent eventWithName:@"event name" valueFromString:[aboveMax stringValue]];
    XCTAssertFalse(event.isValid);

    // Min value
    NSNumber *minValue = @(INT32_MIN);
    event = [UACustomEvent eventWithName:@"event name" valueFromString:[minValue stringValue]];
    XCTAssertEqualObjects(minValue, event.eventValue, @"Event value should be set from a valid numeric string.");
    XCTAssertTrue(event.isValid);

    // Below min
    NSDecimalNumber *belowMin = [NSDecimalNumber decimalNumberWithDecimal:[minValue decimalValue]];
    belowMin = [belowMin decimalNumberBySubtracting:[NSDecimalNumber decimalNumberWithString:@"0.000001"]];
    event = [UACustomEvent eventWithName:@"event name" valueFromString:[belowMin stringValue]];
    XCTAssertFalse(event.isValid);

    // 0
    event = [UACustomEvent eventWithName:@"event name" valueFromString:@"0"];
    XCTAssertEqualObjects(@(0), event.eventValue, @"Event value should be set from a valid numeric string.");
    XCTAssertTrue(event.isValid);

    // nil
    event = [UACustomEvent eventWithName:@"event name" valueFromString:nil];
    XCTAssertTrue(event.isValid);

    // NaN
    event = [UACustomEvent eventWithName:@"event name" valueFromString:@"blah"];
    XCTAssertFalse(event.isValid);
}

/**
 * Test event value from an NSNumber.
 */
- (void)testSetEventValueNSNumber {
    UACustomEvent *event = [UACustomEvent eventWithName:@"event name" value:@(100)];
    XCTAssertTrue(event.isValid);

    // Max value
    NSNumber *maxValue = @(INT32_MAX);
    event = [UACustomEvent eventWithName:@"event name" value:maxValue];
    XCTAssertTrue(event.isValid);

    // Above Max
    NSDecimalNumber *aboveMax = [NSDecimalNumber decimalNumberWithDecimal:[maxValue decimalValue]];
    aboveMax = [aboveMax decimalNumberByAdding:[NSDecimalNumber decimalNumberWithString:@"0.000001"]];
    event = [UACustomEvent eventWithName:@"event name" value:aboveMax];
    XCTAssertFalse(event.isValid);

    // Min value
    NSNumber *minValue = @(INT32_MIN);
    event = [UACustomEvent eventWithName:@"event name" value:minValue];
    XCTAssertTrue(event.isValid);

    // Below min
    NSDecimalNumber *belowMin = [NSDecimalNumber decimalNumberWithDecimal:[minValue decimalValue]];
    belowMin = [belowMin decimalNumberBySubtracting:[NSDecimalNumber decimalNumberWithString:@"0.000001"]];
    event = [UACustomEvent eventWithName:@"event name" value:belowMin];
    XCTAssertFalse(event.isValid);

    // 0
    event = [UACustomEvent eventWithName:@"event name" value:@(0)];
    XCTAssertTrue(event.isValid);

    // nil
    event = [UACustomEvent eventWithName:@"event name" value:nil];
    XCTAssertTrue(event.isValid);

    // NaN
    event = [UACustomEvent eventWithName:@"event name" value:[NSDecimalNumber notANumber]];
    XCTAssertFalse(event.isValid);
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
 * Test event includes conversion send ID if available.
 */
- (void)testConversionSendID {
    self.analytics.conversionSendID = @"send ID";
    UACustomEvent *event = [UACustomEvent eventWithName:@"event name"];

    XCTAssertEqualObjects(@"send ID", [event.data objectForKey:@"conversion_send_id"], @"Send ID should be set.");
}

/**
 * Test setting the event conversion send ID.
 */
- (void)testSettingConversionSendID {
    UACustomEvent *event = [UACustomEvent eventWithName:@"event name"];
    event.conversionSendID = @"directSendID";

    XCTAssertEqualObjects(@"directSendID", [event.data objectForKey:@"conversion_send_id"], @"Send ID should be set.");
}

/**
 * Test event includes conversion push metadata if available.
 */
- (void)testConversionPushMetadata {
    self.analytics.conversionPushMetadata = @"send metadata";
    
    UACustomEvent *event = [UACustomEvent eventWithName:@"event name"];

    XCTAssertEqualObjects(@"send metadata", [event.data objectForKey:@"conversion_metadata"], @"Send Metadata should be set.");
}

/**
 * Test setting the event conversion push metadata.
 */
- (void)testSettingConversionPushMetadata {
    UACustomEvent *event = [UACustomEvent eventWithName:@"event name"];
    event.conversionPushMetadata = @"base64metadataString";

    XCTAssertEqualObjects(@"base64metadataString", [event.data objectForKey:@"conversion_metadata"], @"Push metadata should be set.");
}

/**
 * Test track adds an event to analytics.
 */
- (void)testTrack {
    UACustomEvent *event = [UACustomEvent eventWithName:@"event name"];
    [event track];
    
    XCTAssertEqual(1, self.analytics.events.count);
    XCTAssertEqual(event, self.analytics.events.firstObject);
}

/**
 * Test max total property size is 65536 bytes.
 */
- (void)testMaxTotalPropertySize {
    UACustomEvent *event = [UACustomEvent eventWithName:@"name"];

    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
    
    for (int i = 0; i < 5000; i++) {
        [properties setValue:@324 forKey:[NSString stringWithFormat:@"%d", i]];
    }
    
    event.properties = properties;
    
    XCTAssertTrue(event.isValid);
    
    // Add more properties
    for (int i = 5000; i < 7000; i++) {
        [properties setValue:@324 forKey:[NSString stringWithFormat:@"%d", i]];
    }

    event.properties = properties;
    
    // Should be invalid
    XCTAssertFalse(event.isValid);     
}

@end

