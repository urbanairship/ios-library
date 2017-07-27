/* Copyright 2017 Urban Airship and Contributors */


#import "UABaseTest.h"
#import "UAScheduleDelay.h"
#import "UAUtils.h"

@interface UAScheduleDelayTests : UABaseTest

@end

@implementation UAScheduleDelayTests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testWithJSON {
    NSDictionary *delayJson = @{ UAScheduleDelayRegionKey: @"test region",
                                 UAScheduleDelayScreenKey: @"test screen",
                                 UAScheduleDelaySecondsKey: @(100) };

    NSError *error = nil;
    UAScheduleDelay *delay = [UAScheduleDelay delayWithJSON:delayJson error:&error];

    XCTAssertEqualObjects(delay.screen, @"test screen");
    XCTAssertEqualObjects(delay.regionID, @"test region");
    XCTAssertEqual(delay.seconds, 100);
    XCTAssertEqual(delay.appState, UAScheduleDelayAppStateAny);

    XCTAssertNil(error);
}

- (void)testWithJsonBackgroundState {
    NSDictionary *delayJson = @{ UAScheduleDelayAppStateKey: UAScheduleTriggerAppBackgroundName };

    NSError *error = nil;
    UAScheduleDelay *delay = [UAScheduleDelay delayWithJSON:delayJson error:&error];

    XCTAssertEqual(delay.appState, UAScheduleDelayAppStateBackground);
    XCTAssertNil(error);
}

- (void)testWithJsonForegroundState {
    NSDictionary *delayJson = @{ UAScheduleDelayAppStateKey: UAScheduleTriggerAppForegroundName };

    NSError *error = nil;
    UAScheduleDelay *delay = [UAScheduleDelay delayWithJSON:delayJson error:&error];

    XCTAssertEqual(delay.appState, UAScheduleDelayAppStateForeground);
    XCTAssertNil(error);
}

- (void)testInvalidJSON {
    NSArray *invalidValues = @[
                               // Invalid seconds
                               @{UAScheduleDelaySecondsKey: @"one hundred" },

                               // Invalid screen
                               @{UAScheduleDelayScreenKey: @(1) },

                               //Invalid region
                               @{UAScheduleDelayRegionKey: @{} },

                               //Invalid app_state
                               @{UAScheduleDelayAppStateKey: @"invalid" },

                               // Invalid object
                               @"what" ];


    for (id value in invalidValues) {
        NSError *error;
        XCTAssertNil([UAScheduleDelay delayWithJSON:value error:&error]);
        XCTAssertNotNil(error);
    }
}


@end
