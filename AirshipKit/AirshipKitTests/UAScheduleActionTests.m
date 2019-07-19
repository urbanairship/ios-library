/* Copyright Airship and Contributors */


#import "UABaseTest.h"

#import "UAScheduleAction.h"
#import "UAActionArguments+Internal.h"
#import "UAAutomation.h"
#import "UAirship+Internal.h"
#import "UAUtils+Internal.h"
#import "UASchedule+Internal.h"
#import "UAScheduleInfo+Internal.h"
#import "UAActionScheduleInfo+Internal.h"

@interface UAScheduleActionTests : UABaseTest
@property(nonatomic, strong) UAScheduleAction *action;
@property(nonatomic, strong) id mockAirship;
@property(nonatomic, strong) id mockAutomation;
@end

@implementation UAScheduleActionTests

- (void)setUp {
    [super setUp];

    self.mockAutomation = [self mockForClass:[UAAutomation class]];
    self.mockAirship = [self mockForClass:[UAirship class]];
    [UAirship setSharedAirship:self.mockAirship];
    [[[self.mockAirship stub] andReturn:self.mockAutomation] automation];

    self.action = [[UAScheduleAction alloc] init];
}

- (void)tearDown {
    [self.mockAutomation stopMocking];
    [self.mockAirship stopMocking];
    [super tearDown];
}

/**
 * Test accepts arguments.
 */
- (void)testAcceptsArguments {
    UASituation validSituations[5] = {
        UASituationForegroundPush,
        UASituationBackgroundPush,
        UASituationManualInvocation,
        UASituationWebViewInvocation,
        UASituationAutomation
    };

    UAActionArguments *arguments = [[UAActionArguments alloc] init];
    arguments.situation = UASituationBackgroundInteractiveButton;
    arguments.value = @{ UAActionScheduleInfoActionsKey: @{ @"action_name": @"action_value" },
                         UAScheduleInfoTriggersKey: @[ @{ UAScheduleTriggerTypeKey: UAScheduleTriggerAppForegroundName, UAScheduleTriggerGoalKey: @(1) }] };

    for (int i = 0; i < 5; i++) {
        arguments.situation = validSituations[i];
        XCTAssertTrue([self.action acceptsArguments:arguments], @"action should accept situation %zd", validSituations[i]);
    }
}

/**
 * Test scheduling actions.
 */
- (void)testSchedule {
    NSDictionary *scheduleJSON = @{ UAScheduleInfoGroupKey: @"test group",
                                    UAScheduleInfoLimitKey: @(1),
                                    UAActionScheduleInfoActionsKey: @{ @"action_name": @"action_value" },
                                    UAScheduleInfoEndKey:[[UAUtils ISODateFormatterUTC] stringFromDate:[NSDate dateWithTimeIntervalSinceNow:1000]],
                                    UAScheduleInfoStartKey:[[UAUtils ISODateFormatterUTC] stringFromDate: [NSDate date]],
                                    UAScheduleInfoTriggersKey: @[ @{ UAScheduleTriggerTypeKey: UAScheduleTriggerAppForegroundName, UAScheduleTriggerGoalKey: @(1) }] };

    NSError *error;
    UAActionScheduleInfo *expectedInfo = [UAActionScheduleInfo scheduleInfoWithJSON:scheduleJSON error:&error];
    XCTAssertNil(error);


    __block BOOL actionPerformed = NO;

    UAActionArguments *arguments = [[UAActionArguments alloc] init];
    arguments.situation = UASituationManualInvocation;
    arguments.value = scheduleJSON;

    [[self.mockAutomation expect] scheduleActions:expectedInfo completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(UASchedule *) = obj;
        UASchedule *schedule = [UASchedule scheduleWithIdentifier:@"test" info:expectedInfo metadata:@{}];
        completionBlock(schedule);
        return YES;
    }]];

    [self.action performWithArguments:arguments completionHandler:^(UAActionResult *result) {
        actionPerformed = YES;
        XCTAssertEqualObjects(@"test", result.value);
    }];

    XCTAssertTrue(actionPerformed);
    [self.mockAutomation verify];
}

@end

