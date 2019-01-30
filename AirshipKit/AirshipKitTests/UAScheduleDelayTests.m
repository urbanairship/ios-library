/* Copyright 2010-2019 Urban Airship and Contributors */


#import "UABaseTest.h"
#import "UAScheduleDelay.h"
#import "UAUtils+Internal.h"

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

    NSArray *testScreens = @[@"test screen", @"another test screen"];
    NSDictionary *delayJson = @{ UAScheduleDelayRegionKey: @"test region",
                                 UAScheduleDelayScreensKey: testScreens,
                                 UAScheduleDelaySecondsKey: @(100) };

    NSError *error = nil;
    UAScheduleDelay *delay = [UAScheduleDelay delayWithJSON:delayJson error:&error];

    BOOL arrayMatch = YES;
    for (NSString *screen in delay.screens) {
        if (![testScreens containsObject:screen]) {
            arrayMatch = NO;
        }
    }

    NSString *testScreenString = @"test screen";
    NSDictionary *anotherDelayJson = @{ UAScheduleDelayRegionKey: @"test region",
                                 UAScheduleDelayScreensKey: testScreenString,
                                 UAScheduleDelaySecondsKey: @(100) };

    UAScheduleDelay *anotherDelay = [UAScheduleDelay delayWithJSON:anotherDelayJson error:&error];

    XCTAssertTrue(arrayMatch);
    XCTAssertEqualObjects(testScreenString, anotherDelay.screens.firstObject);
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

                               // Invalid screens
                               @{UAScheduleDelayScreensKey: @(1) },

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
