/* Copyright Airship and Contributors */

#import <XCTest/XCTest.h>
#import "UABaseTest.h"
#import "UAActionSchedule.h"
#import "UASchedule+Internal.h"
#import "NSJSONSerialization+UAAdditions.h"

@interface UAActionScheduleTests : UABaseTest

@end

@implementation UAActionScheduleTests

- (void)testActions {
    id actions = @{@"woot": @"rad"};
    UAActionSchedule *schedule = [UAActionSchedule scheduleWithActions:actions builderBlock:^(UAScheduleBuilder * _Nonnull builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
    }];

    XCTAssertEqualObjects(actions, schedule.actions);
}

- (void)testJSON {
    id actions = @{@"woot": @"rad"};
    UAActionSchedule *schedule = [UAActionSchedule scheduleWithActions:actions builderBlock:^(UAScheduleBuilder * _Nonnull builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
    }];

    XCTAssertEqualObjects([NSJSONSerialization stringWithObject:actions], schedule.dataJSONString);
}

- (void)testInvalidJSON {
    id actions = @{@"woot": self};
    UAActionSchedule *schedule = [UAActionSchedule scheduleWithActions:actions builderBlock:^(UAScheduleBuilder * _Nonnull builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
    }];

    XCTAssertNil(schedule.dataJSONString);
}


@end
