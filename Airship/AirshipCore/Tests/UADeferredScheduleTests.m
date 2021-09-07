/* Copyright Airship and Contributors */

#import <XCTest/XCTest.h>
#import "UABaseTest.h"
#import "UADeferredSchedule+Internal.h"
#import "UASchedule+Internal.h"

@import AirshipCore;

@interface UADeferredScheduleTests : UABaseTest

@end

@implementation UADeferredScheduleTests

- (void)testDeferred {
    id deferred = [UAScheduleDeferredData deferredDataWithURL:[NSURL URLWithString:@"https://airship.com"]
                                           retriableOnTimeout:NO];
    UADeferredSchedule *schedule = [UADeferredSchedule scheduleWithDeferredData:deferred builderBlock:^(UAScheduleBuilder * _Nonnull builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
    }];

    XCTAssertEqualObjects(deferred, schedule.deferredData);
}

- (void)testJSON {
    id deferred = [UAScheduleDeferredData deferredDataWithURL:[NSURL URLWithString:@"https://airship.com"]
                                           retriableOnTimeout:NO];
    UADeferredSchedule *schedule = [UADeferredSchedule scheduleWithDeferredData:deferred builderBlock:^(UAScheduleBuilder * _Nonnull builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
    }];

    XCTAssertEqualObjects([UAJSONUtils stringWithObject:[deferred toJSON]], schedule.dataJSONString);
}

@end
