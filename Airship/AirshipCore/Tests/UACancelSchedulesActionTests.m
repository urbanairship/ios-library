/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UACancelSchedulesAction.h"
#import "UAInAppAutomation+Internal.h"

@import AirshipCore;

@interface UACancelSchedulesActionTests : UABaseTest
@property(nonatomic, strong) UACancelSchedulesAction *action;
@property(nonatomic, strong) id mockAutomation;
@end

@implementation UACancelSchedulesActionTests

- (void)setUp {
    [super setUp];

    self.mockAutomation = [self mockForClass:[UAInAppAutomation class]];
    (void)[[[self.mockAutomation stub] andReturn:self.mockAutomation] shared];
    self.action = [[UACancelSchedulesAction alloc] init];
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


    // Should accept all
    for (int i = 0; i < 5; i++) {
        XCTAssertTrue([self.action acceptsArgumentValue:UACancelSchedulesActionAll situation:validSituations[i]]);
    }

    // Should accept an NSDictionary with "groups"
    for (int i = 0; i < 5; i++) {
        XCTAssertTrue([self.action acceptsArgumentValue:@{ @"groups": @"my group"} situation:validSituations[i]]);
    }

    // Should accept an NSDictionary with "ids"
    for (int i = 0; i < 5; i++) {
        XCTAssertTrue([self.action acceptsArgumentValue:@{ @"ids": @"my id"} situation:validSituations[i]]);
    }

    // Should accept an NSDictionary with "ids" and "groups"
    for (int i = 0; i < 5; i++) {
        id value = @{ @"ids": @"my id", @"groups": @[@"group"]};
        XCTAssertTrue([self.action acceptsArgumentValue:value situation:validSituations[i]]);
    }
}

/**
 * Test canceling all schedules.
 */
- (void)testCancelAll {
    __block BOOL actionPerformed = NO;

    [[self.mockAutomation expect] cancelSchedulesWithType:UAScheduleTypeActions completionHandler:OCMOCK_ANY];

    [self.action performWithArgumentValue:UACancelSchedulesActionAll situation:UAActionSituationManualInvocation pushUserInfo:nil completionHandler:^{
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

    [[self.mockAutomation expect] cancelActionSchedulesWithGroup:@"group 1" completionHandler:OCMOCK_ANY];
    [[self.mockAutomation expect] cancelActionSchedulesWithGroup:@"group 2" completionHandler:OCMOCK_ANY];

    id value = @{UACancelSchedulesActionGroups: @[@"group 1", @"group 2"] };
    [self.action performWithArgumentValue:value
                                situation:UAActionSituationManualInvocation
                             pushUserInfo:nil
                        completionHandler:^{
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

    [[self.mockAutomation expect] cancelScheduleWithID:@"ID 1" completionHandler:OCMOCK_ANY];
    [[self.mockAutomation expect] cancelScheduleWithID:@"ID 2" completionHandler:OCMOCK_ANY];

    id value = @{UACancelSchedulesActionIDs: @[@"ID 1", @"ID 2"] };
    [self.action performWithArgumentValue:value
                                situation:UAActionSituationManualInvocation
                             pushUserInfo:nil
                        completionHandler:^{
        actionPerformed = YES;
    }];

    XCTAssertTrue(actionPerformed);
    [self.mockAutomation verify];
}

@end

