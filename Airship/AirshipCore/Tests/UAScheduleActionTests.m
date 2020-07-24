/* Copyright Airship and Contributors */


#import "UABaseTest.h"

#import "UAScheduleAction.h"
#import "UAActionArguments+Internal.h"
#import "UAInAppAutomation.h"
#import "UAirship+Internal.h"
#import "UAUtils+Internal.h"
#import "UASchedule+Internal.h"

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
    arguments.value = @{ @"actions": @{ @"action_name": @"action_value" },
                         @"triggers": @[ @{ @"type": @"foreground", @"goal": @(1) }] };

    for (int i = 0; i < 5; i++) {
        arguments.situation = validSituations[i];
        XCTAssertTrue([self.action acceptsArguments:arguments], @"action should accept situation %zd", validSituations[i]);
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

    UAActionArguments *arguments = [[UAActionArguments alloc] init];
    arguments.situation = UASituationManualInvocation;
    arguments.value = scheduleJSON;

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

    [self.action performWithArguments:arguments completionHandler:^(UAActionResult *result) {
        actionPerformed = YES;
        XCTAssertEqualObjects(schedule.identifier, result.value);
    }];

    XCTAssertTrue(actionPerformed);
    [self.mockAutomation verify];
}

@end

