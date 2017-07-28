/* Copyright 2017 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UAAccountEventTemplate.h"
#import "UAAnalytics.h"
#import "UAirship.h"
#import "UACustomEvent.h"

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
