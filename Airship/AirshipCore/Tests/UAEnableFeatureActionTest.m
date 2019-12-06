/* Copyright Airship and Contributors */

#import "UABaseTest.h"

#import "UAActionArguments+Internal.h"
#import "UAEnableFeatureAction.h"
#import "UAirship+Internal.h"
#import "UAPush+Internal.h"
#import "UAAPNSRegistration+Internal.h"

@interface UAEnableFeatureActionTest : UABaseTest

@property (nonatomic, strong) UAEnableFeatureAction *action;
@property (nonatomic, strong) UAActionArguments *arguments;

@property(nonatomic, strong) id mockPush;
@property(nonatomic, strong) id mockLocationProvider;
@property(nonatomic, strong) id mockAirship;
@property(nonatomic, strong) id mockPushRegistration;
@property(nonatomic, strong) id mockApplication;

@end

@implementation UAEnableFeatureActionTest

- (void)setUp {
    [super setUp];

    self.action = [[UAEnableFeatureAction alloc] init];

    self.mockPush = [self strictMockForClass:[UAPush class]];

    self.mockLocationProvider = [self mockForProtocol:@protocol(UALocationProvider)];

    self.mockAirship = [self strictMockForClass:[UAirship class]];
    self.mockPushRegistration = [self mockForProtocol:@protocol(UAAPNSRegistrationProtocol)];
    self.mockApplication = [self mockForClass:[UIApplication class]];

    [UAirship setSharedAirship:self.mockAirship];
    [[[self.mockAirship stub] andReturn:self.mockPush] sharedPush];

    [[[self.mockAirship stub] andReturn:self.mockLocationProvider] locationProvider];

    [[[self.mockPush stub] andReturn:self.mockPushRegistration] pushRegistration];
    [[[self.mockApplication stub] andReturn:self.mockApplication] sharedApplication];
}

- (void)tearDown {
    [self.mockPush stopMocking];
    [self.mockLocationProvider stopMocking];
    [self.mockAirship stopMocking];
    [self.mockPushRegistration stopMocking];
    [self.mockApplication stopMocking];

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
    UAActionArguments *arguments = [[UAActionArguments alloc] init];
    arguments.value = UAEnableUserNotificationsActionValue;

    XCTestExpectation *expectation = [self expectationWithDescription:@"action performed"];

    [[self.mockPush expect] userPromptedForNotifications];
    [[self.mockPush expect] setUserPushNotificationsEnabled:YES];
    [[self.mockApplication reject] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]
                                   options:OCMOCK_ANY
                         completionHandler:OCMOCK_ANY];

    [self.action performWithArguments:arguments completionHandler:^(UAActionResult *result) {
        [expectation fulfill];
    }];

    // Wait for the test expectations
    [self waitForTestExpectations];
    [self.mockPush verify];
}

- (void)testEnableUserNotificationsOptedOut {
    UAActionArguments *arguments = [[UAActionArguments alloc] init];
    arguments.value = UAEnableUserNotificationsActionValue;

    XCTestExpectation *settingsOpened = [self expectationWithDescription:@"settings opened"];
    XCTestExpectation *actionPerformed = [self expectationWithDescription:@"action performed"];

    [[[self.mockPushRegistration stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        void (^handler)(UANotificationOptions) = (__bridge void (^)(UANotificationOptions))arg;
        handler(UANotificationOptionNone);
        [settingsOpened fulfill];
    }] getAuthorizedSettingsWithCompletionHandler:OCMOCK_ANY];

    [[[self.mockPush stub] andReturnValue:@YES] userPromptedForNotifications];

    [[self.mockPush expect] setUserPushNotificationsEnabled:YES];
    [[[self.mockApplication stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^handler)(BOOL) = (__bridge void (^)(BOOL))arg;
        handler(YES);
    }] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString] options:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [self.action performWithArguments:arguments completionHandler:^(UAActionResult *result) {
        [actionPerformed fulfill];
    }];

    // Wait for the test expectations
    [self waitForTestExpectations];
    [self.mockPush verify];
}

- (void)testEnableLocation {
    __block BOOL actionPerformed = NO;

    [[[self.mockLocationProvider stub] andReturnValue:@(NO)] isLocationDeniedOrRestricted];

    UAActionArguments *arguments = [[UAActionArguments alloc] init];
    arguments.value = UAEnableLocationActionValue;

    [[self.mockLocationProvider expect] setLocationUpdatesEnabled:YES];
    [[self.mockApplication reject] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]
                                   options:OCMOCK_ANY
                         completionHandler:OCMOCK_ANY];

    [self.action performWithArguments:arguments completionHandler:^(UAActionResult *result) {
        actionPerformed = YES;
    }];

    [self.mockLocationProvider verify];
    XCTAssertTrue(actionPerformed);
}

- (void)testEnableLocationOptedOut {
    __block BOOL actionPerformed = NO;

    [[[self.mockLocationProvider stub] andReturnValue:@(YES)] isLocationDeniedOrRestricted];

    UAActionArguments *arguments = [[UAActionArguments alloc] init];
    arguments.value = UAEnableLocationActionValue;

    [[self.mockLocationProvider expect] setLocationUpdatesEnabled:YES];
    [[[self.mockApplication stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^handler)(BOOL) = (__bridge void (^)(BOOL))arg;
        handler(YES);
    }] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString] options:OCMOCK_ANY completionHandler:OCMOCK_ANY];


    [self.action performWithArguments:arguments completionHandler:^(UAActionResult *result) {
        actionPerformed = YES;
    }];

    [self.mockLocationProvider verify];
    XCTAssertTrue(actionPerformed);
}

- (void)testEnableBackgroundLocation {
    __block BOOL actionPerformed = NO;

    [[[self.mockLocationProvider stub] andReturnValue:@(NO)] isLocationDeniedOrRestricted];

    UAActionArguments *arguments = [[UAActionArguments alloc] init];
    arguments.value = UAEnableBackgroundLocationActionValue;

    [[self.mockLocationProvider expect] setLocationUpdatesEnabled:YES];
    [[self.mockLocationProvider expect] setBackgroundLocationUpdatesAllowed:YES];
    [[self.mockApplication reject] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]
                                   options:OCMOCK_ANY
                         completionHandler:OCMOCK_ANY];

    [self.action performWithArguments:arguments completionHandler:^(UAActionResult *result) {
        actionPerformed = YES;
    }];

    [self.mockLocationProvider verify];
    XCTAssertTrue(actionPerformed);
}

- (void)testEnableBackgroundLocationOptedOut {
    __block BOOL actionPerformed = NO;

    [[[self.mockLocationProvider stub] andReturnValue:@(NO)] isLocationDeniedOrRestricted];

    UAActionArguments *arguments = [[UAActionArguments alloc] init];
    arguments.value = UAEnableBackgroundLocationActionValue;

    [[self.mockLocationProvider expect] setLocationUpdatesEnabled:YES];
    [[self.mockLocationProvider expect] setBackgroundLocationUpdatesAllowed:YES];
    [[[self.mockApplication stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^handler)(BOOL) = (__bridge void (^)(BOOL))arg;
        handler(YES);
    }] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString] options:OCMOCK_ANY completionHandler:OCMOCK_ANY];


    [self.action performWithArguments:arguments completionHandler:^(UAActionResult *result) {
        actionPerformed = YES;
    }];

    [self.mockLocationProvider verify];
    XCTAssertTrue(actionPerformed);
}

@end
