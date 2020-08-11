/* Copyright Airship and Contributors */

#import <XCTest/XCTest.h>
#import "UABaseTest.h"
#import "UAInAppMessageSchedule.h"
#import "UASchedule+Internal.h"
#import "NSJSONSerialization+UAAdditions.h"
#import "UAInAppMessageCustomDisplayContent.h"

@interface UAINAppMessageScheduleTests : UABaseTest

@end

@implementation UAINAppMessageScheduleTests

- (void)testMessage {
    id message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
        builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
        builder.identifier = @"message ID";
    }];

    UAInAppMessageSchedule *schedule = [UAInAppMessageSchedule scheduleWithMessage:message builderBlock:^(UAScheduleBuilder * _Nonnull builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
    }];

    XCTAssertEqualObjects(message, schedule.message);
}

- (void)testJSON {
    id message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
        builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
        builder.identifier = @"message ID";
    }];

    UAInAppMessageSchedule *schedule = [UAInAppMessageSchedule scheduleWithMessage:message builderBlock:^(UAScheduleBuilder * _Nonnull builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
    }];

    XCTAssertEqualObjects([NSJSONSerialization stringWithObject:[message toJSON]], schedule.dataJSONString);
}

@end
