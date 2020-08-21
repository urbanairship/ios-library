/* Copyright Airship and Contributors */

#import <XCTest/XCTest.h>
#import "UABaseTest.h"
#import "UADeferredSchedule+Internal.h"
#import "UASchedule+Internal.h"
#import "NSJSONSerialization+UAAdditions.h"

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

    XCTAssertEqualObjects([NSJSONSerialization stringWithObject:[deferred toJSON]], schedule.dataJSONString);
}

@end
