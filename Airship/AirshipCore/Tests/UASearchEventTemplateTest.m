/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "AirshipTests-Swift.h"

@import AirshipCore;

@interface UASearchEventTemplateTest : UABaseTest
@property(nonatomic, strong) UATestAnalytics *analytics;
@property(nonatomic, strong) UATestAirshipInstance *airship;

@end

@implementation UASearchEventTemplateTest

- (void)setUp {
    [super setUp];
    self.analytics = [[UATestAnalytics alloc] init];
    self.airship = [[UATestAirshipInstance alloc] init];
    self.airship.components = @[self.analytics];
    [self.airship makeShared];
}

/**
 * Test basic search event.
 */
- (void)testBasicSearchEvent {
    UASearchEventTemplate *event = [UASearchEventTemplate template];
    UACustomEvent *customEvent = [event createEvent];

    XCTAssertEqualObjects(@"search", [customEvent.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(@NO, customEvent.data[@"properties"][@"ltv"], @"Property ltv should be NO.");
    XCTAssertEqualObjects(@"search", [customEvent.data objectForKey:@"template_type"], @"Unexpected event template type.");
}

/**
 * Test search event with optional value.
 */
- (void)testSearchEventWithValue {
    UASearchEventTemplate *event = [UASearchEventTemplate templateWithValue: @(INT32_MIN)];
    UACustomEvent *customEvent = [event createEvent];

    XCTAssertEqualObjects(@"search", [customEvent.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(@(INT32_MIN * 1000000.0), [customEvent.data objectForKey:@"event_value"], @"Unexpected event value.");
    XCTAssertEqualObjects(@YES, customEvent.data[@"properties"][@"ltv"], @"Unexpected ltv property.");
    XCTAssertEqualObjects(@"search", [customEvent.data objectForKey:@"template_type"], @"Unexpected event template type.");
}

/**
 * Test search event with optional value and properties.
 */
- (void)testSearchEventWithValueProperties {
    UASearchEventTemplate *eventTemplate = [UASearchEventTemplate template];
    eventTemplate.eventValue = [NSDecimalNumber decimalNumberWithString:@"12345.00"];
    eventTemplate.category = @"search-category";
    eventTemplate.query = @"Sneakers";
    eventTemplate.totalResults = 20;

    UACustomEvent *customEvent = [eventTemplate createEvent];
    [customEvent track];

    XCTAssertEqualObjects(@"search", [customEvent.data objectForKey:@"event_name"], @"Unexpected event name.");
    XCTAssertEqualObjects(@(12345), customEvent.eventValue, @"Unexpected event value.");
    XCTAssertEqualObjects(@YES, customEvent.data[@"properties"][@"ltv"], @"Unexpected ltv property.");
    XCTAssertEqualObjects(@"search-category", customEvent.data[@"properties"][@"category"], @"Unexpected category.");
    XCTAssertEqualObjects(@"Sneakers", customEvent.data[@"properties"][@"query"], @"Unexpected query.");
    XCTAssertEqualObjects(@(20), customEvent.data[@"properties"][@"total_results"], @"Unexpected total results.");
    XCTAssertEqualObjects(@"search", [customEvent.data objectForKey:@"template_type"], @"Unexpected event template type.");
}

@end
