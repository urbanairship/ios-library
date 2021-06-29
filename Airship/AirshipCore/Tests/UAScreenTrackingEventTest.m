/* Copyright Airship and Contributors */

#import "UABaseTest.h"

@import AirshipCore;

@interface UAScreenTrackingEventTest : UABaseTest
@end

@implementation UAScreenTrackingEventTest

/**
 * Test event data directly.
 */
- (void)testScreenTrackingEventData {
    UAScreenTrackingEvent *event = [[UAScreenTrackingEvent alloc] initWithScreen:@"test_screen"
                                                           previousScreen:@"previous_screen"
                                                                startTime:0
                                                                 stopTime:1];

    NSDictionary *expectedData = @{
                                   @"duration":@"1.000",
                                   @"entered_time":@"0.000",
                                   @"exited_time":@"1.000",
                                   @"previous_screen":@"previous_screen",
                                   @"screen":@"test_screen",
                                   };

    XCTAssertEqualObjects(expectedData, event.data);
}

/**
 * Test validity of varying length screen names.
 */
- (void)testScreenValidation {
    NSString *screenName = [@"" stringByPaddingToLength:255 withString:@"test_screen_name" startingAtIndex:0];

    UAScreenTrackingEvent *event = [[UAScreenTrackingEvent alloc] initWithScreen:screenName previousScreen:nil startTime:0 stopTime:1];
    XCTAssertEqualObjects(event.screen, screenName);
    XCTAssertTrue(event.isValid);

    screenName = [@"" stringByPaddingToLength:256 withString:@"test_screen_name" startingAtIndex:0];
    event = [[UAScreenTrackingEvent alloc] initWithScreen:screenName previousScreen:nil startTime:0 stopTime:1];
    XCTAssertFalse(event.isValid);

    screenName = @"";
    event = [[UAScreenTrackingEvent alloc] initWithScreen:screenName previousScreen:nil startTime:0 stopTime:1];
    XCTAssertFalse(event.isValid);
}

/**
 * Test validity of screen tracking events with different stop times
 */
- (void)testStopTimeValidation {
    // Test invalid screen tracking event with stop time equal to start time
    UAScreenTrackingEvent *event = [[UAScreenTrackingEvent alloc] initWithScreen:@"test_screen" previousScreen:nil startTime:0 stopTime:0];
    XCTAssertFalse(event.isValid);

    // Test invalid screen tracking event with stop time before start time
    event = [[UAScreenTrackingEvent alloc] initWithScreen:@"test_screen" previousScreen:nil startTime:1 stopTime:0];
    XCTAssertFalse(event.isValid);

    // Test valid screen tracking event with stop time after start time
    event = [[UAScreenTrackingEvent alloc] initWithScreen:@"test_screen" previousScreen:nil startTime:0 stopTime:1];
    XCTAssertTrue(event.isValid);
}

@end
