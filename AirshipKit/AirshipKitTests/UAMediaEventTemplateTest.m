/* Copyright 2010-2019 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UAMediaEventTemplate.h"
#import "UAAnalytics.h"
#import "UAirship.h"
#import "UACustomEvent.h"

@interface UAMediaEventTemplateTest : UABaseTest
@property (nonatomic, strong) id analytics;
@property (nonatomic, strong) id airship;
@end

@implementation UAMediaEventTemplateTest

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
 * Test basic browsedEvent.
 */
- (void)testBasicBrowsedEvent {
    UAMediaEventTemplate *eventTemplate = [UAMediaEventTemplate browsedTemplate];
    UACustomEvent *customEvent = [eventTemplate createEvent];
    [customEvent track];

    XCTAssertEqualObjects(@"browsed_content", [customEvent.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(@"false", customEvent.data[@"properties"][@"ltv"], @"Property ltv should be NO.");
    XCTAssertEqualObjects(@"media", [customEvent.data objectForKey:@"template_type"], @"Unexpected event template type.");
}

/**
 * Test browsedEvent with optional properties.
 */
- (void)testBrowsedEventWithProperties {
    UAMediaEventTemplate *eventTemplate = [UAMediaEventTemplate browsedTemplate];
    eventTemplate.category = @"media-category";
    eventTemplate.identifier = @"1234";
    eventTemplate.eventDescription = @"Browsed content media event.";
    eventTemplate.type = @"audio type";
    eventTemplate.author = @"The Cool UA";
    eventTemplate.isFeature = YES;
    eventTemplate.publishedDate = @"November 13, 2015";

    UACustomEvent *customEvent = [eventTemplate createEvent];
    [customEvent track];

    XCTAssertEqualObjects(@"browsed_content", [customEvent.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(@"false", customEvent.data[@"properties"][@"ltv"], @"Property ltv should be NO.");
    XCTAssertEqualObjects(@"\"media-category\"", customEvent.data[@"properties"][@"category"], @"Unexpected category.");
    XCTAssertEqualObjects(@"\"1234\"", customEvent.data[@"properties"][@"id"], @"Unexpected ID.");
    XCTAssertEqualObjects(@"\"Browsed content media event.\"", customEvent.data[@"properties"][@"description"], @"Unexpected description.");
    XCTAssertEqualObjects(@"\"audio type\"", customEvent.data[@"properties"][@"type"], @"Unexpected type.");
    XCTAssertEqualObjects(@"\"The Cool UA\"", customEvent.data[@"properties"][@"author"], @"Unexpected author.");
    XCTAssertEqualObjects(@"true", customEvent.data[@"properties"][@"feature"], @"Unexpected feature.");
    XCTAssertEqualObjects(@"\"November 13, 2015\"", customEvent.data[@"properties"][@"published_date"], @"Unexpected published date.");
    XCTAssertEqualObjects(@"media", [customEvent.data objectForKey:@"template_type"], @"Unexpected event template type.");
}

/**
 * Test basic starredEvent.
 */
- (void)testBasicStarredEvent {
    UAMediaEventTemplate *eventTemplate = [UAMediaEventTemplate starredTemplate];
    UACustomEvent *customEvent = [eventTemplate createEvent];
    [customEvent track];

    XCTAssertEqualObjects(@"starred_content", [customEvent.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(@"false", customEvent.data[@"properties"][@"ltv"], @"Property ltv should be NO.");
    XCTAssertEqualObjects(@"media", [customEvent.data objectForKey:@"template_type"], @"Unexpected event template type.");
}

/**
 * Test starredEvent with optional properties.
 */
- (void)testStarredEventWithProperties {
    UAMediaEventTemplate *eventTemplate = [UAMediaEventTemplate starredTemplate];
    eventTemplate.category = @"media-category";
    eventTemplate.identifier = @"1234";
    eventTemplate.eventDescription = @"Starred content media event.";
    eventTemplate.type = @"audio type";
    eventTemplate.author = @"The Cool UA";
    eventTemplate.isFeature = YES;
    eventTemplate.publishedDate = @"November 13, 2015";

    UACustomEvent *customEvent = [eventTemplate createEvent];
    [customEvent track];

    XCTAssertEqualObjects(@"starred_content", [customEvent.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(@"false", customEvent.data[@"properties"][@"ltv"], @"Property ltv should be NO.");
    XCTAssertEqualObjects(@"\"media-category\"", customEvent.data[@"properties"][@"category"], @"Unexpected category.");
    XCTAssertEqualObjects(@"\"1234\"", customEvent.data[@"properties"][@"id"], @"Unexpected ID.");
    XCTAssertEqualObjects(@"\"Starred content media event.\"", customEvent.data[@"properties"][@"description"], @"Unexpected description.");
    XCTAssertEqualObjects(@"\"audio type\"", customEvent.data[@"properties"][@"type"], @"Unexpected type.");
    XCTAssertEqualObjects(@"\"The Cool UA\"", customEvent.data[@"properties"][@"author"], @"Unexpected author.");
    XCTAssertEqualObjects(@"true", customEvent.data[@"properties"][@"feature"], @"Unexpected feature.");
    XCTAssertEqualObjects(@"\"November 13, 2015\"", customEvent.data[@"properties"][@"published_date"], @"Unexpected published date.");
    XCTAssertEqualObjects(@"media", [customEvent.data objectForKey:@"template_type"], @"Unexpected event template type.");
}

/**
 * Test basic sharedEvent.
 */
- (void)testBasicSharedEvent {
    UAMediaEventTemplate *eventTemplate = [UAMediaEventTemplate sharedTemplate];
    UACustomEvent *customEvent = [eventTemplate createEvent];
    [customEvent track];

    XCTAssertEqualObjects(@"shared_content", [customEvent.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(@"false", customEvent.data[@"properties"][@"ltv"], @"Property ltv should be NO.");
    XCTAssertEqualObjects(@"media", [customEvent.data objectForKey:@"template_type"], @"Unexpected event template type.");
}

/**
 * Test sharedEvent with optional properties.
 */
- (void)testSharedEvent {
    UAMediaEventTemplate *eventTemplate = [UAMediaEventTemplate sharedTemplateWithSource:@"facebook" withMedium:@"social"];
    eventTemplate.category = @"media-category";
    eventTemplate.identifier = @"12345";
    eventTemplate.eventDescription = @"Shared content media event.";
    eventTemplate.type = @"video type";
    eventTemplate.author = @"The Fun UA";
    eventTemplate.isFeature = YES;
    eventTemplate.publishedDate = @"November 13, 2015";
    UACustomEvent *customEvent = [eventTemplate createEvent];
    [customEvent track];

    XCTAssertEqualObjects(@"shared_content", [customEvent.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(@"false", customEvent.data[@"properties"][@"ltv"], @"Property ltv should be NO.");
    XCTAssertEqualObjects(@"\"facebook\"", customEvent.data[@"properties"][@"source"], @"Unexpected source.");
    XCTAssertEqualObjects(@"\"social\"", customEvent.data[@"properties"][@"medium"], @"Unexpected medium.");
    XCTAssertEqualObjects(@"\"media-category\"", customEvent.data[@"properties"][@"category"], @"Unexpected category.");
    XCTAssertEqualObjects(@"\"12345\"", customEvent.data[@"properties"][@"id"], @"Unexpected ID.");
    XCTAssertEqualObjects(@"\"Shared content media event.\"", customEvent.data[@"properties"][@"description"], @"Unexpected description.");
    XCTAssertEqualObjects(@"\"video type\"", customEvent.data[@"properties"][@"type"], @"Unexpected type.");
    XCTAssertEqualObjects(@"\"The Fun UA\"", customEvent.data[@"properties"][@"author"], @"Unexpected author.");
    XCTAssertEqualObjects(@"true", customEvent.data[@"properties"][@"feature"], @"Unexpected feature.");
    XCTAssertEqualObjects(@"\"November 13, 2015\"", customEvent.data[@"properties"][@"published_date"], @"Unexpected published date.");
    XCTAssertEqualObjects(@"media", [customEvent.data objectForKey:@"template_type"], @"Unexpected event template type.");
}

/**
 * Test basic consumedEvent.
 */
- (void)testBasicConsumedEvent {
    UAMediaEventTemplate *eventTemplate = [UAMediaEventTemplate consumedTemplate];
    UACustomEvent *customEvent = [eventTemplate createEvent];
    [customEvent track];

    XCTAssertEqualObjects(@"consumed_content", [customEvent.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(@"false", customEvent.data[@"properties"][@"ltv"], @"Property ltv should be NO.");
    XCTAssertEqualObjects(@"media", [customEvent.data objectForKey:@"template_type"], @"Unexpected event template type.");
}

/**
 * Test consumedEvent with optional value from string.
 */
- (void)testConsumedEventWithValueFromString {
    UAMediaEventTemplate *eventTemplate = [UAMediaEventTemplate consumedTemplateWithValueFromString:@"100.00"];
    UACustomEvent *customEvent = [eventTemplate createEvent];
    [customEvent track];

    XCTAssertEqualObjects(@"consumed_content", [customEvent.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(@(100.00), customEvent.eventValue, @"Event value should be set from a valid numeric string.");
    XCTAssertEqualObjects(@"true", customEvent.data[@"properties"][@"ltv"], @"Unexpected ltv property.");
    XCTAssertEqualObjects(@"media", [customEvent.data objectForKey:@"template_type"], @"Unexpected event template type.");
}

/**
 * Test consumedEvent with optional value and properties.
 */
- (void)testConsumedEventWithValueProperties {
    UAMediaEventTemplate *eventTemplate = [UAMediaEventTemplate consumedTemplateWithValue:@(INT32_MIN)];
    eventTemplate.category = @"media-category";
    eventTemplate.identifier = @"12322";
    eventTemplate.eventDescription = @"Consumed content media event.";
    eventTemplate.type = @"audio type";
    eventTemplate.author = @"The Smart UA";
    eventTemplate.isFeature = YES;
    eventTemplate.publishedDate = @"November 13, 2015";
    UACustomEvent *customEvent = [eventTemplate createEvent];
    [customEvent track];

    XCTAssertEqualObjects(@"consumed_content", [customEvent.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(@(INT32_MIN * 1000000.0), [customEvent.data objectForKey:@"event_value"], @"Unexpected event value.");
    XCTAssertEqualObjects(@"true", customEvent.data[@"properties"][@"ltv"], @"Unexpected ltv property.");
    XCTAssertEqualObjects(@"\"media-category\"", customEvent.data[@"properties"][@"category"], @"Unexpected category.");
    XCTAssertEqualObjects(@"\"12322\"", customEvent.data[@"properties"][@"id"], @"Unexpected ID.");
    XCTAssertEqualObjects(@"\"Consumed content media event.\"", customEvent.data[@"properties"][@"description"], @"Unexpected description.");
    XCTAssertEqualObjects(@"\"audio type\"", customEvent.data[@"properties"][@"type"], @"Unexpected type.");
    XCTAssertEqualObjects(@"\"The Smart UA\"", customEvent.data[@"properties"][@"author"], @"Unexpected author.");
    XCTAssertEqualObjects(@"true", customEvent.data[@"properties"][@"feature"], @"Unexpected feature.");
    XCTAssertEqualObjects(@"\"November 13, 2015\"", customEvent.data[@"properties"][@"published_date"], @"Unexpected properties.");
    XCTAssertEqualObjects(@"media", [customEvent.data objectForKey:@"template_type"], @"Unexpected event template type.");
}

@end
