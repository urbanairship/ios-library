/* Copyright 2017 Urban Airship and Contributors */


#import <XCTest/XCTest.h>
#import "UAActionScheduleInfo.h"
#import "UAUtils.h"

@interface UAActionInfoTests : XCTestCase

@end

@implementation UAActionInfoTests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testWithJSON {

    NSDate *end = [NSDate dateWithTimeIntervalSinceNow:1000];
    NSDate *start = [NSDate date];

    NSDictionary *scheduleJSON = @{ UAActionScheduleInfoGroupKey: @"test group",
                                    UAActionScheduleInfoLimitKey: @(1),
                                    UAActionScheduleInfoActionsKey: @{ @"action_name": @"action_value" },
                                    UAActionScheduleInfoEndKey:[[UAUtils ISODateFormatterUTCWithDelimiter] stringFromDate:end],
                                    UAActionScheduleInfoStartKey:[[UAUtils ISODateFormatterUTCWithDelimiter] stringFromDate:start],
                                    UAActionScheduleInfoTriggersKey: @[ @{ UAScheduleTriggerTypeKey: UAScheduleTriggerAppForegroundName, UAScheduleTriggerGoalKey: @(1) }] };

    NSError *error = nil;
    UAActionScheduleInfo *info = [UAActionScheduleInfo actionScheduleInfoWithJSON:scheduleJSON error:&error];

    XCTAssertEqualObjects(info.group, @"test group");
    XCTAssertEqual(info.limit, 1);
    XCTAssertEqualObjects(info.actions, @{ @"action_name": @"action_value" });
    XCTAssertEqualWithAccuracy([info.start timeIntervalSinceNow], [start timeIntervalSinceNow], 1);
    XCTAssertEqualWithAccuracy([info.end timeIntervalSinceNow], [end timeIntervalSinceNow], 1);
    XCTAssertEqual(info.triggers.count, 1);
    XCTAssertNil(error);
}

- (void)testRequiredJSONFields {
    // Minimum required fields
    NSDictionary *validJSON = @{ UAActionScheduleInfoActionsKey: @{ @"action_name": @"action_value" },
                                 UAActionScheduleInfoTriggersKey: @[ @{ UAScheduleTriggerTypeKey: UAScheduleTriggerAppForegroundName, UAScheduleTriggerGoalKey: @(1) }] };
    XCTAssertNotNil([UAActionScheduleInfo actionScheduleInfoWithJSON:validJSON error:nil]);

    for (NSString *key in validJSON.allKeys) {
        NSError *error = nil;
        NSMutableDictionary *invalidJSON = [validJSON mutableCopy];

        // Missing required value
        [invalidJSON removeObjectForKey:key];
        XCTAssertNil([UAActionScheduleInfo actionScheduleInfoWithJSON:invalidJSON error:&error]);
        XCTAssertNotNil(error);

        // Invalid valid
        error = nil;
        invalidJSON[key] = @"what";
        XCTAssertNil([UAActionScheduleInfo actionScheduleInfoWithJSON:invalidJSON error:&error]);
        XCTAssertNotNil(error);
    }
}

@end
