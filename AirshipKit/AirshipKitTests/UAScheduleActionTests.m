/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


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

