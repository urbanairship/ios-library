/* Copyright 2017 Urban Airship and Contributors */

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "UACancelSchedulesAction.h"
#import "UAActionArguments+Internal.h"
#import "UAAutomation.h"
#import "UAirship.h"

@interface UACancelSchedulesActionTests : XCTestCase
@property(nonatomic, strong) UACancelSchedulesAction *action;
@property(nonatomic, strong) id mockAirship;
@property(nonatomic, strong) id mockAutomation;
@end

@implementation UACancelSchedulesActionTests

- (void)setUp {
    [super setUp];

    self.mockAutomation = [OCMockObject niceMockForClass:[UAAutomation class]];
    self.mockAirship = [OCMockObject niceMockForClass:[UAirship class]];
    [[[self.mockAirship stub] andReturn:self.mockAirship] shared];
    [[[self.mockAirship stub] andReturn:self.mockAutomation] automation];

    self.action = [[UACancelSchedulesAction alloc] init];
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


    // Should accept all
    arguments.value = UACancelSchedulesActionAll;
    for (int i = 0; i < 5; i++) {
        arguments.situation = validSituations[i];
        XCTAssertTrue([self.action acceptsArguments:arguments], @"action should accept situation %zd", validSituations[i]);
    }

    // Should accept an NSDictionary with "groups"
    arguments.value = @{ @"groups": @"my group"};
    for (int i = 0; i < 5; i++) {
        arguments.situation = validSituations[i];
        XCTAssertTrue([self.action acceptsArguments:arguments], @"action should accept situation %zd", validSituations[i]);
    }

    // Should accept an NSDictionary with "ids"
    arguments.value = @{ @"ids": @"my id"};
    for (int i = 0; i < 5; i++) {
        arguments.situation = validSituations[i];
        XCTAssertTrue([self.action acceptsArguments:arguments], @"action should accept situation %zd", validSituations[i]);
    }

    // Should accept an NSDictionary with "ids" and "groups"
    arguments.value = @{ @"ids": @"my id", @"groups": @[@"group"]};
    for (int i = 0; i < 5; i++) {
        arguments.situation = validSituations[i];
        XCTAssertTrue([self.action acceptsArguments:arguments], @"action should accept situation %zd", validSituations[i]);
    }
}

/**
 * Test canceling all schedules.
 */
- (void)testCancelAll {
    __block BOOL actionPerformed = NO;

    UAActionArguments *arguments = [[UAActionArguments alloc] init];
    arguments.situation = UASituationManualInvocation;
    arguments.value = UACancelSchedulesActionAll;

    [[self.mockAutomation expect] cancelAll];

    [self.action performWithArguments:arguments completionHandler:^(UAActionResult *result) {
        actionPerformed = YES;
    }];

    XCTAssertTrue(actionPerformed);
    [self.mockAutomation verify];
}

/**
 * Test canceling groups.
 */
- (void)testCancelGroups {
    __block BOOL actionPerformed = NO;

    UAActionArguments *arguments = [[UAActionArguments alloc] init];
    arguments.situation = UASituationManualInvocation;
    arguments.value = @{UACancelSchedulesActionGroups: @[@"group 1", @"group 2"] };

    [[self.mockAutomation expect] cancelSchedulesWithGroup:@"group 1"];
    [[self.mockAutomation expect] cancelSchedulesWithGroup:@"group 2"];

    [self.action performWithArguments:arguments completionHandler:^(UAActionResult *result) {
        actionPerformed = YES;
    }];

    XCTAssertTrue(actionPerformed);
    [self.mockAutomation verify];
}

/**
 * Test canceling IDs.
 */
- (void)testCancelIDs {
    __block BOOL actionPerformed = NO;

    UAActionArguments *arguments = [[UAActionArguments alloc] init];
    arguments.situation = UASituationManualInvocation;
    arguments.value = @{UACancelSchedulesActionIDs: @[@"ID 1", @"ID 2"] };

    [[self.mockAutomation expect] cancelScheduleWithIdentifier:@"ID 1"];
    [[self.mockAutomation expect] cancelScheduleWithIdentifier:@"ID 2"];

    [self.action performWithArguments:arguments completionHandler:^(UAActionResult *result) {
        actionPerformed = YES;
    }];

    XCTAssertTrue(actionPerformed);
    [self.mockAutomation verify];
}

@end

