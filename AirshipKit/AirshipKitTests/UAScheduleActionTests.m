/* Copyright 2017 Urban Airship and Contributors */


#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "UAScheduleAction.h"
#import "UAActionArguments+Internal.h"
#import "UAAutomation.h"
#import "UAirship.h"
#import "UAUtils.h"
#import "UAActionSchedule+Internal.h"

@interface UAScheduleActionTests : XCTestCase
@property(nonatomic, strong) UAScheduleAction *action;
@property(nonatomic, strong) id mockAirship;
@property(nonatomic, strong) id mockAutomation;
@end

@implementation UAScheduleActionTests

- (void)setUp {
    [super setUp];

    self.mockAutomation = [OCMockObject niceMockForClass:[UAAutomation class]];
    self.mockAirship = [OCMockObject niceMockForClass:[UAirship class]];
    [[[self.mockAirship stub] andReturn:self.mockAirship] shared];
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
                         UAActionScheduleInfoTriggersKey: @[ @{ UAScheduleTriggerTypeKey: UAScheduleTriggerAppForegroundName, UAScheduleTriggerGoalKey: @(1) }] };

    for (int i = 0; i < 5; i++) {
        arguments.situation = validSituations[i];
        XCTAssertTrue([self.action acceptsArguments:arguments], @"action should accept situation %zd", validSituations[i]);
    }
}

/**
 * Test scheduling actions.
 */
- (void)testSchedule {
    NSDictionary *scheduleJSON = @{ UAActionScheduleInfoGroupKey: @"test group",
                                    UAActionScheduleInfoLimitKey: @(1),
                                    UAActionScheduleInfoActionsKey: @{ @"action_name": @"action_value" },
                                    UAActionScheduleInfoEndKey:[[UAUtils ISODateFormatterUTC] stringFromDate:[NSDate dateWithTimeIntervalSinceNow:1000]],
                                    UAActionScheduleInfoStartKey:[[UAUtils ISODateFormatterUTC] stringFromDate: [NSDate date]],
                                    UAActionScheduleInfoTriggersKey: @[ @{ UAScheduleTriggerTypeKey: UAScheduleTriggerAppForegroundName, UAScheduleTriggerGoalKey: @(1) }] };

    NSError *error;
    UAActionScheduleInfo *expectedInfo = [UAActionScheduleInfo actionScheduleInfoWithJSON:scheduleJSON error:&error];
    XCTAssertNil(error);


    __block BOOL actionPerformed = NO;

    UAActionArguments *arguments = [[UAActionArguments alloc] init];
    arguments.situation = UASituationManualInvocation;
    arguments.value = scheduleJSON;

    [[self.mockAutomation expect] scheduleActions:expectedInfo completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(UAActionSchedule *) = obj;
        UAActionSchedule *schedule = [UAActionSchedule actionScheduleWithIdentifier:@"test" info:expectedInfo];
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

