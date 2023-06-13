/* Copyright Airship and Contributors */


#import "UABaseTest.h"

#import "UAScheduleAction.h"
#import "UAInAppAutomation.h"
#import "UASchedule+Internal.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif

@interface UAScheduleActionTests : UABaseTest
@property(nonatomic, strong) UAScheduleAction *action;
@property(nonatomic, strong) id mockAirship;
@property(nonatomic, strong) id mockAutomation;
@end

@implementation UAScheduleActionTests

- (void)setUp {
    [super setUp];

    self.mockAutomation = [self mockForClass:[UAInAppAutomation class]];
    [[[self.mockAutomation stub] andReturn:self.mockAutomation] shared];
    self.action = [[UAScheduleAction alloc] init];
}

/**
 * Test accepts arguments.
 */

- (void)testAcceptsArguments {
    UAActionSituation validSituations[5] = {
        UAActionSituationForegroundPush,
        UAActionSituationBackgroundPush,
        UAActionSituationManualInvocation,
        UAActionSituationWebViewInvocation,
        UAActionSituationAutomation
    };

    for (int i = 0; i < 5; i++) {
        id value = @{ @"actions": @{ @"action_name": @"action_value" },
                      @"triggers": @[ @{ @"type": @"foreground", @"goal": @(1) }] };

        XCTAssertTrue([self.action acceptsArgumentValue:value situation:validSituations[i]]);
    }
}

/**
 * Test scheduling actions.
 */
- (void)testSchedule {

    NSDictionary *scheduleJSON = @{ @"group": @"test group",
                                    @"limit": @(1),
                                    @"actions": @{ @"action_name": @"action_value" },
                                    @"end":[[UAUtils ISODateFormatterUTC] stringFromDate:[NSDate dateWithTimeIntervalSince1970:1000]],
                                    @"start":[[UAUtils ISODateFormatterUTC] stringFromDate: [NSDate dateWithTimeIntervalSince1970:1]],
                                    @"triggers": @[ @{ @"type": @"foreground", @"goal": @(1) }] };


    __block BOOL actionPerformed = NO;

    __block UASchedule *schedule;
    [[self.mockAutomation expect] schedule:[OCMArg checkWithBlock:^BOOL(id obj) {
        schedule = (UASchedule *)obj;
        XCTAssertEqualObjects(@"test group", schedule.group);
        XCTAssertEqual(1, schedule.limit);
        XCTAssertEqualObjects([NSDate dateWithTimeIntervalSince1970:1000], schedule.end);
        XCTAssertEqualObjects([NSDate dateWithTimeIntervalSince1970:1], schedule.start);
        XCTAssertEqual(1, schedule.triggers.count);
        XCTAssertEqual(1, [schedule.triggers.firstObject.goal intValue]);
        XCTAssertEqual(UAScheduleTriggerAppForeground, schedule.triggers.firstObject.type);
        return YES;
    }] completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(BOOL) = obj;
        completionBlock(YES);
        return YES;
    }]];

    [self.action performWithArgumentValue:scheduleJSON situation:UAActionSituationManualInvocation pushUserInfo:nil completionHandler:^{
        actionPerformed = YES;
    }];

    XCTAssertTrue(actionPerformed);
    [self.mockAutomation verify];
}

@end

