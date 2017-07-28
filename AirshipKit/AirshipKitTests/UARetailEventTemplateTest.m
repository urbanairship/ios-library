/* Copyright 2017 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UARetailEventTemplate.h"
#import "UAAnalytics.h"
#import "UAirship.h"
#import "UACustomEvent.h"

@interface UARetailEventTemplateTest : UABaseTest
@property (nonatomic, strong) id analytics;
@property (nonatomic, strong) id airship;
@end

@implementation UARetailEventTemplateTest

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
 * Test basic browsed event.
 */
- (void)testBasicBrowsedEvent {
    UARetailEventTemplate *eventTemplate = [UARetailEventTemplate browsedTemplate];
    UACustomEvent *customEvent = [eventTemplate createEvent];
    [customEvent track];

    XCTAssertEqualObjects(@"browsed", [customEvent.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(@"false", customEvent.data[@"properties"][@"ltv"], @"Unexpected ltv property.");
    XCTAssertEqualObjects(@"retail", [customEvent.data objectForKey:@"template_type"], @"Unexpected event template type.");
}

/**
 * Test browsed event with value.
 */
- (void)testBrowsedEventWithValue {
    UARetailEventTemplate *eventTemplate = [UARetailEventTemplate browsedTemplateWithValue:@(INT32_MIN)];
    UACustomEvent *customEvent = [eventTemplate createEvent];
    [customEvent track];

    XCTAssertEqualObjects(@"browsed", [customEvent.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(@(INT32_MIN * 1000000.0), [customEvent.data objectForKey:@"event_value"], @"Unexpected event value.");
    XCTAssertEqualObjects(@"false", customEvent.data[@"properties"][@"ltv"], @"Unexpected ltv property.");
    XCTAssertEqualObjects(@"retail", [customEvent.data objectForKey:@"template_type"], @"Unexpected event template type.");
}

/**
 * Test browsed event with value from string and properties.
 */
- (void)testBrowsedEventWithValueStringProperties {
    UARetailEventTemplate *eventTemplate = [UARetailEventTemplate browsedTemplateWithValueFromString:@"100.00"];
    eventTemplate.category = @"retail-category";
    eventTemplate.identifier = @"12345";
    eventTemplate.eventDescription = @"Browsed retail event.";
    eventTemplate.transactionID = @"1122334455";
    eventTemplate.brand = @"Urban Airship";
    eventTemplate.isNewItem = YES;
    UACustomEvent *customEvent = [eventTemplate createEvent];
    [customEvent track];

    XCTAssertEqualObjects(@"browsed", [customEvent.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(@(100.00), customEvent.eventValue, @"Event value should be set from a valid numeric string.");
    XCTAssertEqualObjects(@"false", customEvent.data[@"properties"][@"ltv"], @"Unexpected ltv property.");
    XCTAssertEqualObjects(@"1122334455", customEvent.transactionID, @"Unexpected transaction ID.");
    XCTAssertEqualObjects(@"\"retail-category\"", customEvent.data[@"properties"][@"category"], @"Unexpected category.");
    XCTAssertEqualObjects(@"\"12345\"", customEvent.data[@"properties"][@"id"], @"Unexpected ID.");
    XCTAssertEqualObjects(@"\"Browsed retail event.\"", customEvent.data[@"properties"][@"description"], @"Unexpected description.");
    XCTAssertEqualObjects(@"\"Urban Airship\"", customEvent.data[@"properties"][@"brand"], @"Unexpected category.");
    XCTAssertEqualObjects(@"true", customEvent.data[@"properties"][@"new_item"], @"Unexpected new item value.");
    XCTAssertEqualObjects(@"retail", [customEvent.data objectForKey:@"template_type"], @"Unexpected event template type.");
}

/**
 * Test added to cart event.
 */
- (void)testAddedToCartEvent {
    UARetailEventTemplate *eventTemplate = [UARetailEventTemplate addedToCartTemplate];
    UACustomEvent *customEvent = [eventTemplate createEvent];
    [customEvent track];

    XCTAssertEqualObjects(@"added_to_cart", [customEvent.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(@"false", customEvent.data[@"properties"][@"ltv"], @"Unexpected ltv property.");
    XCTAssertEqualObjects(@"retail", [customEvent.data objectForKey:@"template_type"], @"Unexpected event template type.");
}

/**
 * Test added to cart event with value.
 */
- (void)testAddedToCartEventWithValue {
    UARetailEventTemplate *eventTemplate = [UARetailEventTemplate addedToCartTemplateWithValue:@(INT32_MIN)];
    UACustomEvent *customEvent = [eventTemplate createEvent];
    [customEvent track];

    XCTAssertEqualObjects(@"added_to_cart", [customEvent.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(@(INT32_MIN * 1000000.0), [customEvent.data objectForKey:@"event_value"], @"Unexpected event value.");
    XCTAssertEqualObjects(@"false", customEvent.data[@"properties"][@"ltv"], @"Unexpected ltv property.");
    XCTAssertEqualObjects(@"retail", [customEvent.data objectForKey:@"template_type"], @"Unexpected event template type.");
}

/**
 * Test added to cart event with value from string and properties.
 */
- (void)testAddedToCartEventWithValueStringProperties {
    UARetailEventTemplate *eventTemplate = [UARetailEventTemplate addedToCartTemplateWithValueFromString:@"100.00"];
    eventTemplate.category = @"retail-category";
    eventTemplate.identifier = @"12345";
    eventTemplate.eventDescription = @"Added to cart retail event.";
    eventTemplate.transactionID = @"1122334455";
    eventTemplate.brand = @"Urban Airship";
    eventTemplate.isNewItem = YES;
    UACustomEvent *customEvent = [eventTemplate createEvent];
    [customEvent track];

    XCTAssertEqualObjects(@"added_to_cart", [customEvent.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(@(100.00), customEvent.eventValue, @"Event value should be set from a valid numeric string.");
    XCTAssertEqualObjects(@"false", customEvent.data[@"properties"][@"ltv"], @"Unexpected ltv property.");
    XCTAssertEqualObjects(@"1122334455", customEvent.transactionID, @"Unexpected transaction ID.");
    XCTAssertEqualObjects(@"\"retail-category\"", customEvent.data[@"properties"][@"category"], @"Unexpected category.");
    XCTAssertEqualObjects(@"\"12345\"", customEvent.data[@"properties"][@"id"], @"Unexpected ID.");
    XCTAssertEqualObjects(@"\"Added to cart retail event.\"", customEvent.data[@"properties"][@"description"], @"Unexpected description.");
    XCTAssertEqualObjects(@"\"Urban Airship\"", customEvent.data[@"properties"][@"brand"], @"Unexpected category.");
    XCTAssertEqualObjects(@"true", customEvent.data[@"properties"][@"new_item"], @"Unexpected new item value.");
    XCTAssertEqualObjects(@"retail", [customEvent.data objectForKey:@"template_type"], @"Unexpected event template type.");
}

/**
 * Test starred product event.
 */
- (void)testStarredProductEvent {
    UARetailEventTemplate *eventTemplate = [UARetailEventTemplate starredProductTemplate];
    UACustomEvent *customEvent = [eventTemplate createEvent];
    [customEvent track];

    XCTAssertEqualObjects(@"starred_product", [customEvent.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(@"false", customEvent.data[@"properties"][@"ltv"], @"Unexpected ltv property.");
    XCTAssertEqualObjects(@"retail", [customEvent.data objectForKey:@"template_type"], @"Unexpected event template type.");
}

/**
 * Test starred product event with value.
 */
- (void)testStarredProductEventWithValue {
    UARetailEventTemplate *eventTemplate = [UARetailEventTemplate starredProductTemplateWithValue:@(INT32_MIN)];
    UACustomEvent *customEvent = [eventTemplate createEvent];
    [customEvent track];

    XCTAssertEqualObjects(@"starred_product", [customEvent.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(@(INT32_MIN * 1000000.0), [customEvent.data objectForKey:@"event_value"], @"Unexpected event value.");
    XCTAssertEqualObjects(@"false", customEvent.data[@"properties"][@"ltv"], @"Unexpected ltv property.");
    XCTAssertEqualObjects(@"retail", [customEvent.data objectForKey:@"template_type"], @"Unexpected event template type.");
}

/**
 * Test starred product event with value from string and properties.
 */
- (void)testStarredProductEventWithValueStringProperties {
    UARetailEventTemplate *eventTemplate = [UARetailEventTemplate starredProductTemplateWithValueFromString:@"100.00"];
    eventTemplate.category = @"retail-category";
    eventTemplate.identifier = @"12345";
    eventTemplate.eventDescription = @"Starred product retail event.";
    eventTemplate.transactionID = @"1122334455";
    eventTemplate.brand = @"Urban Airship";
    eventTemplate.isNewItem = YES;
    UACustomEvent *customEvent = [eventTemplate createEvent];
    [customEvent track];

    XCTAssertEqualObjects(@"starred_product", [customEvent.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(@(100.00), customEvent.eventValue, @"Event value should be set from a valid numeric string.");
    XCTAssertEqualObjects(@"false", customEvent.data[@"properties"][@"ltv"], @"Unexpected ltv property.");
    XCTAssertEqualObjects(@"1122334455", customEvent.transactionID, @"Unexpected transaction ID.");
    XCTAssertEqualObjects(@"\"retail-category\"", customEvent.data[@"properties"][@"category"], @"Unexpected category.");
    XCTAssertEqualObjects(@"\"12345\"", customEvent.data[@"properties"][@"id"], @"Unexpected ID.");
    XCTAssertEqualObjects(@"\"Starred product retail event.\"", customEvent.data[@"properties"][@"description"], @"Unexpected description.");
    XCTAssertEqualObjects(@"\"Urban Airship\"", customEvent.data[@"properties"][@"brand"], @"Unexpected category.");
    XCTAssertEqualObjects(@"true", customEvent.data[@"properties"][@"new_item"], @"Unexpected new item value.");
    XCTAssertEqualObjects(@"retail", [customEvent.data objectForKey:@"template_type"], @"Unexpected event template type.");
}

/**
 * Test purchased event.
 */
- (void)testPurchasedEvent {
    UARetailEventTemplate *eventTemplate = [UARetailEventTemplate purchasedTemplate];
    UACustomEvent *customEvent = [eventTemplate createEvent];
    [customEvent track];

    XCTAssertEqualObjects(@"purchased", [customEvent.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(@"false", customEvent.data[@"properties"][@"ltv"], @"Unexpected ltv property.");
    XCTAssertEqualObjects(@"retail", [customEvent.data objectForKey:@"template_type"], @"Unexpected event template type.");
}

/**
 * Test purchased event with value.
 */
- (void)testPurchasedEventWithValue {
    UARetailEventTemplate *eventTemplate = [UARetailEventTemplate purchasedTemplateWithValue:@(INT32_MIN)];
    UACustomEvent *customEvent = [eventTemplate createEvent];
    [customEvent track];

    XCTAssertEqualObjects(@"purchased", [customEvent.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(@(INT32_MIN * 1000000.0), [customEvent.data objectForKey:@"event_value"], @"Unexpected event value.");
    XCTAssertEqualObjects(@"true", customEvent.data[@"properties"][@"ltv"], @"Unexpected ltv property.");
    XCTAssertEqualObjects(@"retail", [customEvent.data objectForKey:@"template_type"], @"Unexpected event template type.");
}

/**
 * Test purchased event with value from string and properties.
 */
- (void)testPurchasedEventWithValueStringProperties {
    UARetailEventTemplate *eventTemplate = [UARetailEventTemplate purchasedTemplateWithValueFromString:@"100.00"];
    eventTemplate.category = @"retail-category";
    eventTemplate.identifier = @"12345";
    eventTemplate.eventDescription = @"Purchased retail event.";
    eventTemplate.transactionID = @"1122334455";
    eventTemplate.brand = @"Urban Airship";
    eventTemplate.isNewItem = YES;
    UACustomEvent *customEvent = [eventTemplate createEvent];
    [customEvent track];

    XCTAssertEqualObjects(@"purchased", [customEvent.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(@(100.00), customEvent.eventValue, @"Event value should be set from a valid numeric string.");
    XCTAssertEqualObjects(@"true", customEvent.data[@"properties"][@"ltv"], @"Unexpected ltv property.");
    XCTAssertEqualObjects(@"1122334455", customEvent.transactionID, @"Unexpected transaction ID.");
    XCTAssertEqualObjects(@"\"retail-category\"", customEvent.data[@"properties"][@"category"], @"Unexpected category.");
    XCTAssertEqualObjects(@"\"12345\"", customEvent.data[@"properties"][@"id"], @"Unexpected ID.");
    XCTAssertEqualObjects(@"\"Purchased retail event.\"", customEvent.data[@"properties"][@"description"], @"Unexpected description.");
    XCTAssertEqualObjects(@"\"Urban Airship\"", customEvent.data[@"properties"][@"brand"], @"Unexpected category.");
    XCTAssertEqualObjects(@"true", customEvent.data[@"properties"][@"new_item"], @"Unexpected new item value.");
    XCTAssertEqualObjects(@"retail", [customEvent.data objectForKey:@"template_type"], @"Unexpected event template type.");
}

/**
 * Test shared product event.
 */
- (void)testSharedProductEvent {
    UARetailEventTemplate *eventTemplate = [UARetailEventTemplate sharedProductTemplate];
    UACustomEvent *customEvent = [eventTemplate createEvent];
    [customEvent track];

    XCTAssertEqualObjects(@"shared_product", [customEvent.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(@"false", customEvent.data[@"properties"][@"ltv"], @"Unexpected ltv property.");
    XCTAssertEqualObjects(@"retail", [customEvent.data objectForKey:@"template_type"], @"Unexpected event template type.");
}

/**
 * Test shared product event with value.
 */
- (void)testSharedProductEventWithValue {
    UARetailEventTemplate *eventTemplate = [UARetailEventTemplate sharedProductTemplateWithValue:@(INT32_MIN)];
    UACustomEvent *customEvent = [eventTemplate createEvent];
    [customEvent track];

    XCTAssertEqualObjects(@"shared_product", [customEvent.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(@(INT32_MIN * 1000000.0), [customEvent.data objectForKey:@"event_value"], @"Unexpected event value.");
    XCTAssertEqualObjects(@"false", customEvent.data[@"properties"][@"ltv"], @"Unexpected ltv property.");
    XCTAssertEqualObjects(@"retail", [customEvent.data objectForKey:@"template_type"], @"Unexpected event template type.");
}

/**
 * Test shared product event with value from string and properties.
 */
- (void)testSharedProductEventWithValueStringProperties {
    UARetailEventTemplate *eventTemplate = [UARetailEventTemplate sharedProductTemplateWithValueFromString:@"100.00"];
    eventTemplate.category = @"retail-category";
    eventTemplate.identifier = @"12345";
    eventTemplate.eventDescription = @"Shared product retail event.";
    eventTemplate.transactionID = @"1122334455";
    eventTemplate.brand = @"Urban Airship";
    eventTemplate.isNewItem = YES;
    UACustomEvent *customEvent = [eventTemplate createEvent];
    [customEvent track];

    XCTAssertEqualObjects(@"shared_product", [customEvent.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(@(100.00), customEvent.eventValue, @"Event value should be set from a valid numeric string.");
    XCTAssertEqualObjects(@"false", customEvent.data[@"properties"][@"ltv"], @"Unexpected ltv property.");
    XCTAssertEqualObjects(@"1122334455", customEvent.transactionID, @"Unexpected transaction ID.");
    XCTAssertEqualObjects(@"\"retail-category\"", customEvent.data[@"properties"][@"category"], @"Unexpected category.");
    XCTAssertEqualObjects(@"\"12345\"", customEvent.data[@"properties"][@"id"], @"Unexpected ID.");
    XCTAssertEqualObjects(@"\"Shared product retail event.\"", customEvent.data[@"properties"][@"description"], @"Unexpected description.");
    XCTAssertEqualObjects(@"\"Urban Airship\"", customEvent.data[@"properties"][@"brand"], @"Unexpected category.");
    XCTAssertEqualObjects(@"true", customEvent.data[@"properties"][@"new_item"], @"Unexpected new item value.");
    XCTAssertEqualObjects(@"retail", [customEvent.data objectForKey:@"template_type"], @"Unexpected event template type.");
}

/**
 * Test shared product event with source and medium.
 */
- (void)testSharedProductEventSourceMedium {
    UARetailEventTemplate *eventTemplate = [UARetailEventTemplate sharedProductTemplateWithSource:@"facebook" withMedium:@"social"];
    UACustomEvent *customEvent = [eventTemplate createEvent];
    [customEvent track];

    XCTAssertEqualObjects(@"shared_product", [customEvent.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(@"false", customEvent.data[@"properties"][@"ltv"], @"Unexpected ltv property.");
    XCTAssertEqualObjects(@"\"facebook\"", customEvent.data[@"properties"][@"source"], @"Unexpected source.");
    XCTAssertEqualObjects(@"\"social\"", customEvent.data[@"properties"][@"medium"], @"Unexpected medium.");
    XCTAssertEqualObjects(@"retail", [customEvent.data objectForKey:@"template_type"], @"Unexpected event template type.");
}

/**
 * Test shared product event with value, source and medium.
 */
- (void)testSharedProductEventWithValueSourceMedium {
    UARetailEventTemplate *eventTemplate = [UARetailEventTemplate sharedProductTemplateWithValue:@(INT32_MIN) withSource:@"facebook" withMedium:@"social"];
    UACustomEvent *customEvent = [eventTemplate createEvent];
    [customEvent track];

    XCTAssertEqualObjects(@"shared_product", [customEvent.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(@(INT32_MIN * 1000000.0), [customEvent.data objectForKey:@"event_value"], @"Unexpected event value.");
    XCTAssertEqualObjects(@"false", customEvent.data[@"properties"][@"ltv"], @"Unexpected ltv property.");
    XCTAssertEqualObjects(@"\"facebook\"", customEvent.data[@"properties"][@"source"], @"Unexpected source.");
    XCTAssertEqualObjects(@"\"social\"", customEvent.data[@"properties"][@"medium"], @"Unexpected medium.");
    XCTAssertEqualObjects(@"retail", [customEvent.data objectForKey:@"template_type"], @"Unexpected event template type.");
}

/**
 * Test shared product event with value from string, source and medium.
 */
- (void)testSharedProductEventWithValueStringPropertiesSourceMedium {
    UARetailEventTemplate *eventTemplate = [UARetailEventTemplate sharedProductTemplateWithValueFromString:@"100.00" withSource:@"facebook" withMedium:@"social"];
    eventTemplate.category = @"retail-category";
    eventTemplate.identifier = @"12345";
    eventTemplate.eventDescription = @"Shared product retail event.";
    eventTemplate.transactionID = @"1122334455";
    eventTemplate.brand = @"Urban Airship";
    eventTemplate.isNewItem = YES;
    UACustomEvent *customEvent = [eventTemplate createEvent];
    [customEvent track];

    XCTAssertEqualObjects(@"shared_product", [customEvent.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(@(100.00), customEvent.eventValue, @"Event value should be set from a valid numeric string.");
    XCTAssertEqualObjects(@"false", customEvent.data[@"properties"][@"ltv"], @"Unexpected ltv property.");
    XCTAssertEqualObjects(@"1122334455", customEvent.transactionID, @"Unexpected transaction ID.");
    XCTAssertEqualObjects(@"\"facebook\"", customEvent.data[@"properties"][@"source"], @"Unexpected source.");
    XCTAssertEqualObjects(@"\"social\"", customEvent.data[@"properties"][@"medium"], @"Unexpected medium.");
    XCTAssertEqualObjects(@"\"retail-category\"", customEvent.data[@"properties"][@"category"], @"Unexpected category.");
    XCTAssertEqualObjects(@"\"12345\"", customEvent.data[@"properties"][@"id"], @"Unexpected ID.");
    XCTAssertEqualObjects(@"\"Shared product retail event.\"", customEvent.data[@"properties"][@"description"], @"Unexpected description.");
    XCTAssertEqualObjects(@"\"Urban Airship\"", customEvent.data[@"properties"][@"brand"], @"Unexpected category.");
    XCTAssertEqualObjects(@"true", customEvent.data[@"properties"][@"new_item"], @"Unexpected new item value.");
    XCTAssertEqualObjects(@"retail", [customEvent.data objectForKey:@"template_type"], @"Unexpected event template type.");
}

@end
