/* Copyright 2017 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UAScheduleInfo+Internal.h"
#import "UAActionScheduleInfo+Internal.h"
#import "UAUtils.h"

@interface UAActionInfoTests : UABaseTest

@end

@implementation UAActionInfoTests

- (void)testWithJSON {

    NSDate *end = [NSDate dateWithTimeIntervalSinceNow:1000];
    NSDate *start = [NSDate date];

    NSDictionary *scheduleJSON = @{ UAScheduleInfoGroupKey: @"test group",
                                    UAScheduleInfoLimitKey: @(1),
                                    UAActionScheduleInfoActionsKey: @{ @"action_name": @"action_value" },
                                    UAScheduleInfoEndKey:[[UAUtils ISODateFormatterUTCWithDelimiter] stringFromDate:end],
                                    UAScheduleInfoStartKey:[[UAUtils ISODateFormatterUTCWithDelimiter] stringFromDate:start],
                                    UAScheduleInfoTriggersKey: @[ @{ UAScheduleTriggerTypeKey: UAScheduleTriggerAppForegroundName, UAScheduleTriggerGoalKey: @(1) }],
                                    UAScheduleInfoEditGracePeriodKey: @(1),
                                    UAScheduleInfoIntervalKey: @(20)
                                    };

    NSError *error = nil;
    UAActionScheduleInfo *info = [UAActionScheduleInfo scheduleInfoWithJSON:scheduleJSON error:&error];

    XCTAssertEqualObjects(info.group, @"test group");
    XCTAssertEqual(info.limit, 1);
    XCTAssertEqualObjects(info.actions, @{ @"action_name": @"action_value" });
    XCTAssertEqualWithAccuracy([info.start timeIntervalSinceNow], [start timeIntervalSinceNow], 1);
    XCTAssertEqualWithAccuracy([info.end timeIntervalSinceNow], [end timeIntervalSinceNow], 1);
    XCTAssertEqualWithAccuracy(info.editGracePeriod, 86400, 1);
    XCTAssertEqualWithAccuracy(info.interval, 20, 1);

    XCTAssertEqual(info.triggers.count, 1);
    XCTAssertNil(error);
}

- (void)testRequiredJSONFields {
    // Minimum required fields
    NSDictionary *validJSON = @{ UAActionScheduleInfoActionsKey: @{ @"action_name": @"action_value" },
                                 UAScheduleInfoTriggersKey: @[ @{ UAScheduleTriggerTypeKey: UAScheduleTriggerAppForegroundName, UAScheduleTriggerGoalKey: @(1) }] };
    XCTAssertNotNil([UAActionScheduleInfo scheduleInfoWithJSON:validJSON error:nil]);

    for (NSString *key in validJSON.allKeys) {
        NSError *error = nil;
        NSMutableDictionary *invalidJSON = [validJSON mutableCopy];

        // Missing required value
        [invalidJSON removeObjectForKey:key];
        XCTAssertNil([UAActionScheduleInfo scheduleInfoWithJSON:invalidJSON error:&error]);
        XCTAssertNotNil(error);

        // Invalid valid
        error = nil;
        invalidJSON[key] = @"what";
        XCTAssertNil([UAActionScheduleInfo scheduleInfoWithJSON:invalidJSON error:&error]);
        XCTAssertNotNil(error);
    }
}

@end
