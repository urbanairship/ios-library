/* Copyright 2017 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UAInAppMessageAudienceChecks+Internal.h"
#import "UAInAppMessageAudience+Internal.h"
#import "UAVersionMatcher+Internal.h"
#import "UALocation+Internal.h"
#import "UAirship+Internal.h"
#import "UAPush+Internal.h"
#import "UAInAppMessageTagSelector.h"
#import "UAApplicationMetrics+Internal.h"

@interface UAInAppMessageAudienceChecksTest : UABaseTest

@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) id mockLocationManager;

@end

@implementation UAInAppMessageAudienceChecksTest

- (void)setUp {
    [super setUp];

    self.mockAirship = [self mockForClass:[UAirship class]];
    [UAirship setSharedAirship:self.mockAirship];

    self.mockLocationManager = [self mockForClass:[CLLocationManager class]];

}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testEmptyAudience {
    UAInAppMessageAudience *audience = [UAInAppMessageAudience audienceWithBuilderBlock:^(UAInAppMessageAudienceBuilder * _Nonnull builder) {
    }];
    
    XCTAssertTrue([UAInAppMessageAudienceChecks checkDisplayAudienceConditions:audience]);
}

- (void)testLocationOptIn {
    [[[self.mockLocationManager stub] andReturnValue:@(kCLAuthorizationStatusAuthorizedAlways)] authorizationStatus];

    // setup
    UAInAppMessageAudience *requiresOptedIn = [UAInAppMessageAudience audienceWithBuilderBlock:^(UAInAppMessageAudienceBuilder * _Nonnull builder) {
        builder.locationOptIn = @YES;
    }];
    
    UAInAppMessageAudience *requiresOptedOut = [UAInAppMessageAudience audienceWithBuilderBlock:^(UAInAppMessageAudienceBuilder * _Nonnull builder) {
        builder.locationOptIn = @NO;
    }];
    
    id mockLocation = [self strictMockForClass:[UALocation class]];
    [[[mockLocation stub] andReturnValue:@YES] isLocationUpdatesEnabled];
    [[[self.mockAirship stub] andReturn:mockLocation] sharedLocation];

    // test
    XCTAssertTrue([UAInAppMessageAudienceChecks checkDisplayAudienceConditions:requiresOptedIn]);
    XCTAssertFalse([UAInAppMessageAudienceChecks checkDisplayAudienceConditions:requiresOptedOut]);
}

- (void)testLocationOptOut {
    // setup
    UAInAppMessageAudience *requiresOptedIn = [UAInAppMessageAudience audienceWithBuilderBlock:^(UAInAppMessageAudienceBuilder * _Nonnull builder) {
        builder.locationOptIn = @YES;
    }];
    
    UAInAppMessageAudience *requiresOptedOut = [UAInAppMessageAudience audienceWithBuilderBlock:^(UAInAppMessageAudienceBuilder * _Nonnull builder) {
        builder.locationOptIn = @NO;
    }];
    
    id mockLocation = [self strictMockForClass:[UALocation class]];
    [[[mockLocation stub] andReturnValue:@NO] isLocationUpdatesEnabled];
    [[[self.mockAirship stub] andReturn:mockLocation] sharedLocation];
    
    // test
    XCTAssertFalse([UAInAppMessageAudienceChecks checkDisplayAudienceConditions:requiresOptedIn]);
    XCTAssertTrue([UAInAppMessageAudienceChecks checkDisplayAudienceConditions:requiresOptedOut]);
}

- (void)testNotificationOptIn {
    // setup
    UAInAppMessageAudience *requiresOptedIn = [UAInAppMessageAudience audienceWithBuilderBlock:^(UAInAppMessageAudienceBuilder * _Nonnull builder) {
        builder.notificationsOptIn = @YES;
    }];
    
    UAInAppMessageAudience *requiresOptedOut = [UAInAppMessageAudience audienceWithBuilderBlock:^(UAInAppMessageAudienceBuilder * _Nonnull builder) {
        builder.notificationsOptIn = @NO;
    }];
    
    id mockPush = [self mockForClass:[UAPush class]];
    [[[mockPush stub] andReturnValue:@YES] userPushNotificationsEnabled];
    [[[mockPush stub] andReturnValue:@(UANotificationOptionAlert)] authorizedNotificationOptions];
    [[[self.mockAirship stub] andReturn:mockPush] sharedPush];
    
    // test
    XCTAssertTrue([UAInAppMessageAudienceChecks checkDisplayAudienceConditions:requiresOptedIn]);
    XCTAssertFalse([UAInAppMessageAudienceChecks checkDisplayAudienceConditions:requiresOptedOut]);
}

- (void)testNotificationOptOut {
    // setup
    UAInAppMessageAudience *requiresOptedIn = [UAInAppMessageAudience audienceWithBuilderBlock:^(UAInAppMessageAudienceBuilder * _Nonnull builder) {
        builder.notificationsOptIn = @YES;
    }];
    
    UAInAppMessageAudience *requiresOptedOut = [UAInAppMessageAudience audienceWithBuilderBlock:^(UAInAppMessageAudienceBuilder * _Nonnull builder) {
        builder.notificationsOptIn = @NO;
    }];
    
    id mockPush = [self strictMockForClass:[UAPush class]];
    [[[mockPush stub] andReturnValue:@NO] userPushNotificationsEnabled];
    [[[self.mockAirship stub] andReturn:mockPush] sharedPush];
    
    // test
    XCTAssertFalse([UAInAppMessageAudienceChecks checkDisplayAudienceConditions:requiresOptedIn]);
    XCTAssertTrue([UAInAppMessageAudienceChecks checkDisplayAudienceConditions:requiresOptedOut]);
}

- (void)testNewUser {
    // setup
    UAInAppMessageAudience *requiresNewUser = [UAInAppMessageAudience audienceWithBuilderBlock:^(UAInAppMessageAudienceBuilder * _Nonnull builder) {
        builder.isNewUser = @YES;
    }];

    UAInAppMessageAudience *requiresExistingUser = [UAInAppMessageAudience audienceWithBuilderBlock:^(UAInAppMessageAudienceBuilder * _Nonnull builder) {
        builder.isNewUser = @NO;
    }];

    // test
    XCTAssertFalse([UAInAppMessageAudienceChecks checkScheduleAudienceConditions:requiresNewUser isNewUser:NO]);
    XCTAssertTrue([UAInAppMessageAudienceChecks checkScheduleAudienceConditions:requiresExistingUser isNewUser:NO]);
    XCTAssertTrue([UAInAppMessageAudienceChecks checkScheduleAudienceConditions:requiresNewUser isNewUser:YES]);
    XCTAssertFalse([UAInAppMessageAudienceChecks checkScheduleAudienceConditions:requiresExistingUser isNewUser:YES]);
}

- (void)testTagSelector {
    // setup
    NSMutableArray<NSString *> *tags = [NSMutableArray array];
    
    id mockPush = [self mockForClass:[UAPush class]];
    [[[mockPush stub] andDo:^(NSInvocation *invocation) {
        [invocation setReturnValue:(void *)&tags];
    }] tags];
    [[[self.mockAirship stub] andReturn:mockPush] sharedPush];
    
    UAInAppMessageAudience *audience = [UAInAppMessageAudience audienceWithBuilderBlock:^(UAInAppMessageAudienceBuilder * _Nonnull builder) {
        builder.tagSelector = [UAInAppMessageTagSelector tag:@"expected tag"];
    }];
    
    // test
    XCTAssertFalse([UAInAppMessageAudienceChecks checkDisplayAudienceConditions:audience]);

    [tags addObject:@"expected tag"];
    XCTAssertTrue([UAInAppMessageAudienceChecks checkDisplayAudienceConditions:audience]);
}

- (void)testLanguageIDs {
    // tests
    UAInAppMessageAudience *audience = [UAInAppMessageAudience audienceWithBuilderBlock:^(UAInAppMessageAudienceBuilder * _Nonnull builder) {
        builder.languageTags = @[@"en-US"];
    }];
    XCTAssertTrue([UAInAppMessageAudienceChecks checkDisplayAudienceConditions:audience]);

    audience = [UAInAppMessageAudience audienceWithBuilderBlock:^(UAInAppMessageAudienceBuilder * _Nonnull builder) {
        builder.languageTags = @[@"fr_CA",@"en"];
    }];
    XCTAssertTrue([UAInAppMessageAudienceChecks checkDisplayAudienceConditions:audience]);
    
    audience = [UAInAppMessageAudience audienceWithBuilderBlock:^(UAInAppMessageAudienceBuilder * _Nonnull builder) {
        builder.languageTags = @[@"fr",@"de-CH"];
    }];
    XCTAssertFalse([UAInAppMessageAudienceChecks checkDisplayAudienceConditions:audience]);
}

- (void)testAppVersion {
    // setup
    __block NSString *mockVersion;
    id mockApplicationMetrics = [self mockForClass:[UAApplicationMetrics class]];
    [[[mockApplicationMetrics stub] andDo:^(NSInvocation *invocation) {
        [invocation setReturnValue:(void *)&mockVersion];
    }] currentAppVersion];
    [[[self.mockAirship stub] andReturn:mockApplicationMetrics] applicationMetrics];
    
    UAInAppMessageAudience *audience = [UAInAppMessageAudience audienceWithBuilderBlock:^(UAInAppMessageAudienceBuilder * _Nonnull builder) {
        builder.versionMatcher = [UAVersionMatcher matcherWithVersionConstraint:@"[1.0, 2.0]"];
    }];
    
    // test
    mockVersion = @"1.0";
    XCTAssertTrue([UAInAppMessageAudienceChecks checkDisplayAudienceConditions:audience]);
    
    mockVersion = @"2";
    XCTAssertTrue([UAInAppMessageAudienceChecks checkDisplayAudienceConditions:audience]);
    
    mockVersion = @"3";
    XCTAssertFalse([UAInAppMessageAudienceChecks checkDisplayAudienceConditions:audience]);
}


@end
