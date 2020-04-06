/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UACustomEvent+Internal.h"
#import "UAAnalytics.h"
#import "UAirship+Internal.h"
#import "NSJSONSerialization+UAAdditions.h"

@interface UACustomEventTest : UABaseTest
@property (nonatomic, strong) id analytics;
@property (nonatomic, strong) id airship;

@end

@implementation UACustomEventTest

- (void)setUp {
    [super setUp];

    self.analytics = [self mockForClass:[UAAnalytics class]];
    self.airship = [self mockForClass:[UAirship class]];
    [[[self.airship stub] andReturn:self.analytics] sharedAnalytics];
    [UAirship setSharedAirship:self.airship];
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
    [[[self.analytics stub] andReturn:@"send ID"] conversionSendID];
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
    [[[self.analytics stub] andReturn:@"send metadata"] conversionPushMetadata];
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
    [[self.analytics expect] addEvent:event];
    [event track];
    [self.analytics verify];
}

/**
 * Test setting the string array properties leaves it untouched in the event's data.
 */
- (void)testSetStringArrayProperty {
    NSArray *expectedValue = @[@"string", @"true", @"false", @"123"];

    UACustomEvent *event = [UACustomEvent eventWithName:@"event name"];
    [event setStringArrayProperty:expectedValue forKey:@"array"];

    id eventValue = event.data[@"properties"][@"array"];
    XCTAssertEqualObjects(expectedValue, eventValue);
    XCTAssertTrue(event.isValid);
}

/**
 * Test setting the string property stringifies it in the event's data.
 */
- (void)testSetStringProperty {
    UACustomEvent *event = [UACustomEvent eventWithName:@"event name"];
    [event setStringProperty:@"some string" forKey:@"string"];

    id eventValue = event.data[@"properties"][@"string"];
    XCTAssertEqualObjects(@"some string", eventValue);
    XCTAssertTrue(event.isValid);
}


/**
 * Test setting the string property stringifies it in the event's data.
 */
- (void)testSetBoolProperty {
    UACustomEvent *event = [UACustomEvent eventWithName:@"event name"];
    [event setBoolProperty:true forKey:@"true"];
    [event setBoolProperty:false forKey:@"false"];
    [event setBoolProperty:YES forKey:@"YES"];
    [event setBoolProperty:NO forKey:@"NO"];

    id eventValue = event.data[@"properties"][@"true"];
    XCTAssertEqualObjects(@YES, eventValue);

    eventValue = event.data[@"properties"][@"false"];
    XCTAssertEqualObjects(@NO, eventValue);

    eventValue = event.data[@"properties"][@"YES"];
    XCTAssertEqualObjects(@YES, eventValue);

    eventValue = event.data[@"properties"][@"NO"];
    XCTAssertEqualObjects(@NO, eventValue);

    XCTAssertTrue(event.isValid);
}


/**
 * Test setting the number property stringifies it in the event's data.
 */
- (void)testSetNumberProperty {
    UACustomEvent *event = [UACustomEvent eventWithName:@"event name"];
    [event setNumberProperty:[NSNumber numberWithBool:YES] forKey:@"bool"];
    [event setNumberProperty:[NSNumber numberWithChar:'c'] forKey:@"char"];
    [event setNumberProperty:[NSNumber numberWithDouble:123.456789] forKey:@"double"];
    [event setNumberProperty:[NSNumber numberWithFloat:123.4f] forKey:@"float"];
    [event setNumberProperty:[NSNumber numberWithInt:123] forKey:@"int"];
    [event setNumberProperty:[NSNumber numberWithInteger:1234] forKey:@"integer"];
    [event setNumberProperty:[NSNumber numberWithLong:123l] forKey:@"long"];
    [event setNumberProperty:[NSNumber numberWithLongLong:123l] forKey:@"long long"];
    [event setNumberProperty:[NSNumber numberWithShort:1] forKey:@"short"];
    [event setNumberProperty:[NSNumber numberWithUnsignedChar:'c'] forKey:@"unsigned char"];
    [event setNumberProperty:[NSNumber numberWithUnsignedInt:123] forKey:@"unsigned int"];
    [event setNumberProperty:[NSNumber numberWithUnsignedInteger:123] forKey:@"unsigned int"];
    [event setNumberProperty:[NSNumber numberWithUnsignedLong:123l] forKey:@"unsigned long"];
    [event setNumberProperty:[NSNumber numberWithUnsignedLongLong:123l] forKey:@"unsigned long long"];
    [event setNumberProperty:[NSNumber numberWithUnsignedShort:1] forKey:@"unsigned short"];

    // Number booleans are treated as booleans
    id eventValue = event.data[@"properties"][@"bool"];
    XCTAssertEqualObjects(@YES, eventValue);

    eventValue = event.data[@"properties"][@"char"];
    XCTAssertEqualObjects(@99, eventValue);

    eventValue = event.data[@"properties"][@"double"];
    XCTAssertEqualObjects(@123.456789, eventValue);

    eventValue = event.data[@"properties"][@"float"];
    XCTAssertEqual(@"123.4".floatValue, [eventValue floatValue]);

    eventValue = event.data[@"properties"][@"int"];
    XCTAssertEqualObjects(@123, eventValue);

    eventValue = event.data[@"properties"][@"integer"];
    XCTAssertEqualObjects(@1234, eventValue);

    eventValue = event.data[@"properties"][@"long"];
    XCTAssertEqualObjects(@123, eventValue);

    eventValue = event.data[@"properties"][@"long long"];
    XCTAssertEqualObjects(@123, eventValue);

    eventValue = event.data[@"properties"][@"short"];
    XCTAssertEqualObjects(@1, eventValue);

    eventValue = event.data[@"properties"][@"unsigned char"];
    XCTAssertEqualObjects(@99, eventValue);

    eventValue = event.data[@"properties"][@"unsigned int"];
    XCTAssertEqualObjects(@123, eventValue);

    eventValue = event.data[@"properties"][@"unsigned long"];
    XCTAssertEqualObjects(@123, eventValue);

    eventValue = event.data[@"properties"][@"unsigned long long"];
    XCTAssertEqualObjects(@123, eventValue);

    eventValue = event.data[@"properties"][@"unsigned short"];
    XCTAssertEqualObjects(@1, eventValue);

    XCTAssertTrue(event.isValid);
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

/**
 * Test event.isValid is false when property size exceeds max total property size.
 */
- (void)testStringArrayPropertiesMaxStringLength {
    UACustomEvent *event = [UACustomEvent eventWithName:@"name"];

    NSMutableArray *array = [NSMutableArray array];

    // Add a array with a string at max characters
    [array addObject:[@"" stringByPaddingToLength:255 withString:@"MAX_LENGTH" startingAtIndex:0]];
    [event setStringArrayProperty:array forKey:@"at_max"];

    XCTAssertTrue(event.isValid);
}

@end

