/* Copyright 2018 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UAScreenTrackingEvent+Internal.h"

@interface UAScreenTrackingEventTest : UABaseTest

@end

@implementation UAScreenTrackingEventTest

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

/**
 * Test event data directly.
 */
- (void)testScreenTrackingEventData {
    UAScreenTrackingEvent *event = [UAScreenTrackingEvent eventWithScreen:@"test_screen" startTime:0];
    event.stopTime = 1;
    event.previousScreen = @"previous_screen";

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
- (void)testSetScreen {
    NSString *screenName = [@"" stringByPaddingToLength:255 withString:@"test_screen_name" startingAtIndex:0];

    UAScreenTrackingEvent *event = [UAScreenTrackingEvent eventWithScreen:screenName startTime:0];
    XCTAssertEqualObjects(event.screen, screenName);
    event.stopTime = 1;
    XCTAssertTrue(event.isValid);

    screenName = [@"" stringByPaddingToLength:256 withString:@"test_screen_name" startingAtIndex:0];
    event = [UAScreenTrackingEvent eventWithScreen:screenName startTime:0];
    XCTAssertEqualObjects(event.screen, screenName);
    event.stopTime = 1;
    XCTAssertFalse(event.isValid);

    screenName = @"";
    event = [UAScreenTrackingEvent eventWithScreen:screenName startTime:0];
    XCTAssertEqualObjects(event.screen, screenName);
    event.stopTime = 1;
    XCTAssertFalse(event.isValid);
}

/**
 * Test validity of screen tracking events with different stop times
 */
- (void)testSetStopTime {
    // Test invalid screen tracking event with no stop time
    UAScreenTrackingEvent *event = [UAScreenTrackingEvent eventWithScreen:@"test_screen" startTime:0];
    XCTAssertFalse(event.isValid);

    // Test invalid screen tracking event with stop time equal to start time
    event = [UAScreenTrackingEvent eventWithScreen:@"test_screen" startTime:0];
    event.stopTime = 0;
    XCTAssertFalse(event.isValid);

    // Test invalid screen tracking event with stop time before start time
    event = [UAScreenTrackingEvent eventWithScreen:@"test_screen" startTime:1];
    event.stopTime = 0;
    XCTAssertFalse(event.isValid);

    // Test valid screen tracking event with stop time after start time
    event = [UAScreenTrackingEvent eventWithScreen:@"test_screen" startTime:0];
    event.stopTime = 1;
    XCTAssertTrue(event.isValid);
}

@end
