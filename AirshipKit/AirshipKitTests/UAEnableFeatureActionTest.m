/* Copyright 2017 Urban Airship and Contributors */

#import "UABaseTest.h"

#import "UAActionArguments+Internal.h"
#import "UAEnableFeatureAction.h"
#import "UAirship+Internal.h"
#import "UAPush.h"
#import "UALocation.h"

@interface UAEnableFeatureActionTest : UABaseTest

@property (nonatomic, strong) UAEnableFeatureAction *action;
@property (nonatomic, strong) UAActionArguments *arguments;

@property(nonatomic, strong) id mockPush;
@property(nonatomic, strong) id mockLocation;
@property(nonatomic, strong) id mockAirship;

@end

@implementation UAEnableFeatureActionTest

- (void)setUp {
    [super setUp];

    self.action = [[UAEnableFeatureAction alloc] init];

    self.mockPush = [self strictMockForClass:[UAPush class]];
    self.mockLocation = [self strictMockForClass:[UALocation class]];
    self.mockAirship = [self strictMockForClass:[UAirship class]];

    [UAirship setSharedAirship:self.mockAirship];
    [[[self.mockAirship stub] andReturn:self.mockPush] sharedPush];
    [[[self.mockAirship stub] andReturn:self.mockLocation] sharedLocation];
}

- (void)tearDown {
    [self.mockPush stopMocking];
    [self.mockLocation stopMocking];
    [self.mockAirship stopMocking];
    [UAirship setSharedAirship:nil];
    [super tearDown];
}

- (void)testAcceptsArguments {
    UAActionArguments *arguments = [[UAActionArguments alloc] init];

    UASituation validSituations[6] = {
        UASituationManualInvocation,
        UASituationForegroundPush,
        UASituationForegroundInteractiveButton,
        UASituationLaunchedFromPush,
        UASituationWebViewInvocation,
        UASituationAutomation
    };

    UASituation invalidSituations[2] = {
        UASituationBackgroundInteractiveButton,
        UASituationBackgroundPush,
    };

    NSArray *validValues = @[UAEnableLocationActionValue, UAEnableUserNotificationsActionValue, UAEnableBackgroundLocationActionValue];

    for (id value in validValues) {
        arguments.value = value;


        for (int i = 0; i < 6; i++) {
            arguments.situation = validSituations[i];
            XCTAssertTrue([self.action acceptsArguments:arguments], @"action should accept situation %zd", validSituations[i]);
        }

        for (int i = 0; i < 2; i++) {
            arguments.situation = invalidSituations[i];
            XCTAssertFalse([self.action acceptsArguments:arguments], @"action should not accept situation %zd", invalidSituations[i]);
        }
    }

    // Verify invalid value
    arguments.situation = UASituationManualInvocation;
    arguments.value = @"Invalid argument";
    XCTAssertFalse([self.action acceptsArguments:arguments], @"action should not accept invalid arguments");
}


- (void)testEnableUserNotifications {
    __block BOOL actionPerformed = NO;

    UAActionArguments *arguments = [[UAActionArguments alloc] init];
    arguments.value = UAEnableUserNotificationsActionValue;

    [[self.mockPush expect] setUserPushNotificationsEnabled:YES];
    [self.action performWithArguments:arguments completionHandler:^(UAActionResult *result) {
        actionPerformed = YES;
    }];

    [self.mockPush verify];
    XCTAssertTrue(actionPerformed);
}

- (void)testEnableLocation {
    __block BOOL actionPerformed = NO;

    UAActionArguments *arguments = [[UAActionArguments alloc] init];
    arguments.value = UAEnableLocationActionValue;

    [[self.mockLocation expect] setLocationUpdatesEnabled:YES];
    [self.action performWithArguments:arguments completionHandler:^(UAActionResult *result) {
        actionPerformed = YES;
    }];

    [self.mockLocation verify];
    XCTAssertTrue(actionPerformed);
}

- (void)testEnableBackgroundLocation {
    __block BOOL actionPerformed = NO;

    UAActionArguments *arguments = [[UAActionArguments alloc] init];
    arguments.value = UAEnableBackgroundLocationActionValue;

    [[self.mockLocation expect] setLocationUpdatesEnabled:YES];
    [[self.mockLocation expect] setBackgroundLocationUpdatesAllowed:YES];

    [self.action performWithArguments:arguments completionHandler:^(UAActionResult *result) {
        actionPerformed = YES;
    }];

    [self.mockLocation verify];
    XCTAssertTrue(actionPerformed);
}

@end
