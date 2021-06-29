/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UAAccountEventTemplate.h"
#import "UAAnalytics.h"
#import "UAirship.h"

@import AirshipCore;

@interface UAAccountEventTemplateTest : UABaseTest
@property (nonatomic, strong) id analytics;
@property (nonatomic, strong) id airship;
@end

@implementation UAAccountEventTemplateTest

- (void)setUp {
    [super setUp];
    self.analytics = [self mockForClass:[UAAnalytics class]];
    self.airship = [self strictMockForClass:[UAirship class]];
    [[[self.airship stub] andReturn:self.airship] shared];
    [[[self.airship stub] andReturn:self.analytics] analytics];
}

/**
 * Test basic registered account event with no optional value or properties.
 */
- (void)testBasicRegisteredAccountEvent {
    UAAccountEventTemplate *event = [UAAccountEventTemplate registeredTemplate];
    UACustomEvent *customEvent = [event createEvent];

    XCTAssertEqualObjects(@"registered_account", [customEvent.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(@NO, customEvent.data[@"properties"][@"ltv"], @"Property ltv should be NO.");
    XCTAssertEqualObjects(@"account", [customEvent.data objectForKey:@"template_type"], @"Unexpected event template type.");
}

/**
 * Test registered account event with optional value from string.
 */
- (void)testRegisteredAccountEventWithValueFromString {
    UAAccountEventTemplate *event = [UAAccountEventTemplate registeredTemplateWithValueFromString:@"100.00"];
    UACustomEvent *customEvent = [event createEvent];

    XCTAssertEqualObjects(@"registered_account", [customEvent.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(@(100.00), customEvent.eventValue, @"Event value should be set from a valid numeric string.");
    XCTAssertEqualObjects(@YES, customEvent.data[@"properties"][@"ltv"], @"Unexpected ltv property.");
    XCTAssertEqualObjects(@"account", [customEvent.data objectForKey:@"template_type"], @"Unexpected event template type.");
}

/**
 * Test registered account event with optional value.
 */
- (void)testRegisteredAccountEventWithValue {
    UAAccountEventTemplate *event = [UAAccountEventTemplate registeredTemplateWithValue:@(INT32_MIN)];
    UACustomEvent *customEvent = [event createEvent];

    XCTAssertEqualObjects(@"registered_account", [customEvent.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(@(INT32_MIN * 1000000.0), [customEvent.data objectForKey:@"event_value"], @"Unexpected event value.");
    XCTAssertEqualObjects(@YES, customEvent.data[@"properties"][@"ltv"], @"Unexpected ltv property.");
    XCTAssertEqualObjects(@"account", [customEvent.data objectForKey:@"template_type"], @"Unexpected event template type.");
}

/**
 * Test registered account event with optional value and properties.
 */
- (void)testRegisteredAccountEventWithValueProperties {
    UAAccountEventTemplate *eventTemplate = [UAAccountEventTemplate registeredTemplate];
    eventTemplate.eventValue = [NSDecimalNumber decimalNumberWithString:@"12345.00"];
    eventTemplate.transactionID = @"1212";
    eventTemplate.category = @"Premium";

    UACustomEvent *customEvent = [eventTemplate createEvent];
    [customEvent track];

    XCTAssertEqualObjects(@"registered_account", [customEvent.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(@(12345), customEvent.eventValue, @"Unexpected event value.");
    XCTAssertEqualObjects(@YES, customEvent.data[@"properties"][@"ltv"], @"Unexpected ltv property.");
    XCTAssertEqualObjects(@"1212", customEvent.transactionID, @"Unexpected transaction ID.");
    XCTAssertEqualObjects(@"Premium", customEvent.data[@"properties"][@"category"], @"Unexpected category.");
    XCTAssertEqualObjects(@"account", [customEvent.data objectForKey:@"template_type"], @"Unexpected event template type.");
}

/**
 * Test basic logged in account event with no optional value or properties.
 */
- (void)testBasicLoggedInAccountEvent {
    UAAccountEventTemplate *event = [UAAccountEventTemplate loggedInTemplate];
    UACustomEvent *customEvent = [event createEvent];

    XCTAssertEqualObjects(@"logged_in", [customEvent.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(@NO, customEvent.data[@"properties"][@"ltv"], @"Property ltv should be NO.");
    XCTAssertEqualObjects(@"account", [customEvent.data objectForKey:@"template_type"], @"Unexpected event template type.");
}

/**
 * Test logged in account event with optional value from string.
 */
- (void)testLoggedInAccountEventWithValueFromString {
    UAAccountEventTemplate *event = [UAAccountEventTemplate loggedInTemplateWithValueFromString:@"100.00"];
    UACustomEvent *customEvent = [event createEvent];

    XCTAssertEqualObjects(@"logged_in", [customEvent.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(@(100.00), customEvent.eventValue, @"Event value should be set from a valid numeric string.");
    XCTAssertEqualObjects(@YES, customEvent.data[@"properties"][@"ltv"], @"Unexpected ltv property.");
    XCTAssertEqualObjects(@"account", [customEvent.data objectForKey:@"template_type"], @"Unexpected event template type.");
}

/**
 * Test logged in account event with optional value.
 */
- (void)testLoggedInAccountEventWithValue {
    UAAccountEventTemplate *event = [UAAccountEventTemplate loggedInTemplateWithValue:@(INT32_MIN)];
    UACustomEvent *customEvent = [event createEvent];

    XCTAssertEqualObjects(@"logged_in", [customEvent.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(@(INT32_MIN * 1000000.0), [customEvent.data objectForKey:@"event_value"], @"Unexpected event value.");
    XCTAssertEqualObjects(@YES, customEvent.data[@"properties"][@"ltv"], @"Unexpected ltv property.");
    XCTAssertEqualObjects(@"account", [customEvent.data objectForKey:@"template_type"], @"Unexpected event template type.");
}

/**
 * Test logged in account event with optional value and properties.
 */
- (void)testLoggedInAccountEventWithValueProperties {
    UAAccountEventTemplate *eventTemplate = [UAAccountEventTemplate loggedInTemplate];
    eventTemplate.eventValue = [NSDecimalNumber decimalNumberWithString:@"12345.00"];
    eventTemplate.transactionID = @"1212";
    eventTemplate.category = @"Premium";
    eventTemplate.userID = @"FakeUserID";
    eventTemplate.type = @"FakeType";

    UACustomEvent *customEvent = [eventTemplate createEvent];
    [customEvent track];

    XCTAssertEqualObjects(@"logged_in", [customEvent.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(@(12345), customEvent.eventValue, @"Unexpected event value.");
    XCTAssertEqualObjects(@YES, customEvent.data[@"properties"][@"ltv"], @"Unexpected ltv property.");
    XCTAssertEqualObjects(@"1212", customEvent.transactionID, @"Unexpected transaction ID.");
    XCTAssertEqualObjects(@"Premium", customEvent.data[@"properties"][@"category"], @"Unexpected category.");
    XCTAssertEqualObjects(@"account", [customEvent.data objectForKey:@"template_type"], @"Unexpected event template type.");
    XCTAssertEqualObjects(@"FakeUserID", customEvent.data[@"properties"][@"user_id"], @"Unexpected user ID.");
    XCTAssertEqualObjects(@"FakeType", customEvent.data[@"properties"][@"type"], @"Unexpected type.");
}

/**
 * Test basic logged out account event with no optional value or properties.
 */
- (void)testBasicLoggedOutAccountEvent {
    UAAccountEventTemplate *event = [UAAccountEventTemplate loggedOutTemplate];
    UACustomEvent *customEvent = [event createEvent];

    XCTAssertEqualObjects(@"logged_out", [customEvent.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(@NO, customEvent.data[@"properties"][@"ltv"], @"Property ltv should be NO.");
    XCTAssertEqualObjects(@"account", [customEvent.data objectForKey:@"template_type"], @"Unexpected event template type.");
}

/**
 * Test logged out account event with optional value from string.
 */
- (void)testLoggedOutAccountEventWithValueFromString {
    UAAccountEventTemplate *event = [UAAccountEventTemplate loggedOutTemplateWithValueFromString:@"100.00"];
    UACustomEvent *customEvent = [event createEvent];

    XCTAssertEqualObjects(@"logged_out", [customEvent.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(@(100.00), customEvent.eventValue, @"Event value should be set from a valid numeric string.");
    XCTAssertEqualObjects(@YES, customEvent.data[@"properties"][@"ltv"], @"Unexpected ltv property.");
    XCTAssertEqualObjects(@"account", [customEvent.data objectForKey:@"template_type"], @"Unexpected event template type.");
}

/**
 * Test logged out account event with optional value.
 */
- (void)testLoggedOutAccountEventWithValue {
    UAAccountEventTemplate *event = [UAAccountEventTemplate loggedOutTemplateWithValue:@(INT32_MIN)];
    UACustomEvent *customEvent = [event createEvent];

    XCTAssertEqualObjects(@"logged_out", [customEvent.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(@(INT32_MIN * 1000000.0), [customEvent.data objectForKey:@"event_value"], @"Unexpected event value.");
    XCTAssertEqualObjects(@YES, customEvent.data[@"properties"][@"ltv"], @"Unexpected ltv property.");
    XCTAssertEqualObjects(@"account", [customEvent.data objectForKey:@"template_type"], @"Unexpected event template type.");
}

/**
 * Test logged out account event with optional value and properties.
 */
- (void)testLoggedOutAccountEventWithValueProperties {
    UAAccountEventTemplate *eventTemplate = [UAAccountEventTemplate loggedOutTemplate];
    eventTemplate.eventValue = [NSDecimalNumber decimalNumberWithString:@"12345.00"];
    eventTemplate.transactionID = @"1212";
    eventTemplate.category = @"Premium";
    eventTemplate.userID = @"FakeUserID";
    eventTemplate.type = @"FakeType";

    UACustomEvent *customEvent = [eventTemplate createEvent];
    [customEvent track];

    XCTAssertEqualObjects(@"logged_out", [customEvent.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(@(12345), customEvent.eventValue, @"Unexpected event value.");
    XCTAssertEqualObjects(@YES, customEvent.data[@"properties"][@"ltv"], @"Unexpected ltv property.");
    XCTAssertEqualObjects(@"1212", customEvent.transactionID, @"Unexpected transaction ID.");
    XCTAssertEqualObjects(@"Premium", customEvent.data[@"properties"][@"category"], @"Unexpected category.");
    XCTAssertEqualObjects(@"account", [customEvent.data objectForKey:@"template_type"], @"Unexpected event template type.");
    XCTAssertEqualObjects(@"FakeUserID", customEvent.data[@"properties"][@"user_id"], @"Unexpected user ID.");
    XCTAssertEqualObjects(@"FakeType", customEvent.data[@"properties"][@"type"], @"Unexpected type.");
}

@end
