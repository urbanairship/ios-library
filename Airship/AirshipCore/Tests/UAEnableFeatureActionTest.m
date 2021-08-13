/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UAAirshipBaseTest.h"

#import "UAActionArguments+Internal.h"
#import "UAirship+Internal.h"
#import "UAPush.h"

@import AirshipCore;

@interface UAEnableFeatureActionTest : UAAirshipBaseTest

@property (nonatomic, strong) UAEnableFeatureAction *action;
@property (nonatomic, strong) UAActionArguments *arguments;

@property(nonatomic, strong) id mockPush;
@property(nonatomic, strong) id mockLocationProvider;
@property(nonatomic, strong) id mockAirship;
@property(nonatomic, strong) id mockApplication;
@property(nonatomic, strong) UAPrivacyManager *privacyManager;

@end

@implementation UAEnableFeatureActionTest

- (void)setUp {
    [super setUp];

    self.action = [[UAEnableFeatureAction alloc] init];

    self.mockPush = [self strictMockForClass:[UAPush class]];

    self.mockLocationProvider = [self mockForProtocol:@protocol(UALocationProvider)];

    self.mockAirship = [self strictMockForClass:[UAirship class]];
    self.mockApplication = [self mockForClass:[UIApplication class]];
    self.privacyManager = [[UAPrivacyManager alloc] initWithDataStore:self.dataStore defaultEnabledFeatures:UAFeaturesNone];

    [UAirship setSharedAirship:self.mockAirship];
    [[[self.mockAirship stub] andReturn:self.mockPush] sharedPush];

    [[[self.mockAirship stub] andReturn:self.mockLocationProvider] locationProvider];
    [[[self.mockAirship stub] andReturn:self.privacyManager] privacyManager];

    [[[self.mockApplication stub] andReturn:self.mockApplication] sharedApplication];
}

- (void)tearDown {
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

    NSArray *validValues = @[
        UAEnableFeatureAction.userNotificationsActionValue,
        UAEnableFeatureAction.backgroundLocationActionValue,
        UAEnableFeatureAction.locationActionValue
    ];

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
    arguments.value = UAEnableFeatureAction.userNotificationsActionValue;

    XCTestExpectation *expectation = [self expectationWithDescription:@"action performed"];

    [[self.mockPush expect] userPromptedForNotifications];
    [[self.mockPush expect] setUserPushNotificationsEnabled:YES];
    [[[self.mockPush stub] andReturnValue:OCMOCK_VALUE(UAAuthorizedNotificationSettingsAlert)] authorizedNotificationSettings];

    [[self.mockApplication reject] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]
                                   options:OCMOCK_ANY
                         completionHandler:OCMOCK_ANY];

    [self.action performWithArguments:arguments completionHandler:^(UAActionResult *result) {
        [expectation fulfill];
    }];

    // Wait for the test expectations
    [self waitForTestExpectations];
    [self.mockPush verify];
    
    XCTAssertTrue([self.privacyManager isEnabled:UAFeaturesPush]);
}

- (void)testEnableUserNotificationsOptedOut {
    UAActionArguments *arguments = [[UAActionArguments alloc] init];
    arguments.value = UAEnableFeatureAction.userNotificationsActionValue;

    XCTestExpectation *actionPerformed = [self expectationWithDescription:@"action performed"];

    [[[self.mockPush stub] andReturnValue:@YES] userPromptedForNotifications];
    [[[self.mockPush stub] andReturnValue:OCMOCK_VALUE(UAAuthorizedNotificationSettingsNone)] authorizedNotificationSettings];

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
    XCTAssertTrue([self.privacyManager isEnabled:UAFeaturesPush]);
}

- (void)testEnableLocation {
    __block BOOL actionPerformed = NO;

    [[[self.mockLocationProvider stub] andReturnValue:@(NO)] isLocationDeniedOrRestricted];

    UAActionArguments *arguments = [[UAActionArguments alloc] init];
    arguments.value = UAEnableFeatureAction.locationActionValue;

    [[self.mockLocationProvider expect] setLocationUpdatesEnabled:YES];

    [[self.mockApplication reject] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]
                                   options:OCMOCK_ANY
                         completionHandler:OCMOCK_ANY];

    [self.action performWithArguments:arguments completionHandler:^(UAActionResult *result) {
        actionPerformed = YES;
    }];

    [self.mockLocationProvider verify];
    XCTAssertTrue(actionPerformed);
    XCTAssertTrue([self.privacyManager isEnabled:UAFeaturesLocation]);
}

- (void)testEnableLocationOptedOut {
    __block BOOL actionPerformed = NO;

    [[[self.mockLocationProvider stub] andReturnValue:@(YES)] isLocationDeniedOrRestricted];

    UAActionArguments *arguments = [[UAActionArguments alloc] init];
    arguments.value = UAEnableFeatureAction.locationActionValue;

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
    XCTAssertTrue([self.privacyManager isEnabled:UAFeaturesLocation]);
}

- (void)testEnableBackgroundLocation {
    __block BOOL actionPerformed = NO;

    [[[self.mockLocationProvider stub] andReturnValue:@(NO)] isLocationDeniedOrRestricted];

    UAActionArguments *arguments = [[UAActionArguments alloc] init];
    arguments.value = UAEnableFeatureAction.backgroundLocationActionValue;

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
    XCTAssertTrue([self.privacyManager isEnabled:UAFeaturesLocation]);
}

- (void)testEnableBackgroundLocationOptedOut {
    __block BOOL actionPerformed = NO;

    [[[self.mockLocationProvider stub] andReturnValue:@(NO)] isLocationDeniedOrRestricted];

    UAActionArguments *arguments = [[UAActionArguments alloc] init];
    arguments.value = UAEnableFeatureAction.backgroundLocationActionValue;
    
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
    XCTAssertTrue([self.privacyManager isEnabled:UAFeaturesLocation]);
}

@end
