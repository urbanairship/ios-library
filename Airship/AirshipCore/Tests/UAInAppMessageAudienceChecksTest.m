/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UAScheduleAudienceChecks+Internal.h"
#import "UAScheduleAudience+Internal.h"
#import "UAVersionMatcher.h"
#import "UAirship+Internal.h"
#import "UAPush+Internal.h"
#import "UATagSelector.h"
#import "UAApplicationMetrics.h"
#import "UAJSONPredicate.h"

@interface UAScheduleAudienceChecksTest : UABaseTest

@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) id mockLocationProvider;
@property (nonatomic, strong) id mockPush;
@property (nonatomic, strong) id mockChannel;
@property (nonatomic, assign) BOOL isDataCollectionEnabled;

@end

@implementation UAScheduleAudienceChecksTest

- (void)setUp {
    [super setUp];

    self.isDataCollectionEnabled = YES;

    self.mockAirship = [self mockForClass:[UAirship class]];
    self.mockPush = [self mockForClass:[UAPush class]];
    self.mockChannel = [self mockForClass:[UAChannel class]];

    [[[self.mockAirship stub] andReturn:self.mockPush] sharedPush];
    [[[self.mockAirship stub] andReturn:self.mockChannel] sharedChannel];

    UA_WEAKIFY(self)
    [[[self.mockAirship stub] andDo:^(NSInvocation *invocation) {
        UA_STRONGIFY(self)
        BOOL enabled = self.isDataCollectionEnabled;
        [invocation setReturnValue:(void *)&enabled];
    }] isDataCollectionEnabled];

    [UAirship setSharedAirship:self.mockAirship];

    self.mockLocationProvider = [self mockForProtocol:@protocol(UALocationProvider)];
    [[[self.mockAirship stub] andReturn:self.mockLocationProvider] locationProvider];
}

- (void)testEmptyAudience {
    UAScheduleAudience *audience = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder * _Nonnull builder) {
    }];
    
    XCTAssertTrue([UAScheduleAudienceChecks checkDisplayAudienceConditions:audience]);
}

- (void)testLocationOptIn {
    // setup
    UAScheduleAudience *requiresOptedIn = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder * _Nonnull builder) {
        builder.locationOptIn = @YES;
    }];
    
    UAScheduleAudience *requiresOptedOut = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder * _Nonnull builder) {
        builder.locationOptIn = @NO;
    }];
    
    [[[self.mockLocationProvider stub] andReturnValue:@YES] isLocationOptedIn];
    [[[self.mockLocationProvider stub] andReturnValue:@YES] isLocationUpdatesEnabled];

    // test
    XCTAssertTrue([UAScheduleAudienceChecks checkDisplayAudienceConditions:requiresOptedIn]);
    XCTAssertFalse([UAScheduleAudienceChecks checkDisplayAudienceConditions:requiresOptedOut]);
}

- (void)testLocationOptInWhenDataCollectionDisabled {
    self.isDataCollectionEnabled = NO;

    // setup
    UAScheduleAudience *requiresOptedIn = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder * _Nonnull builder) {
        builder.locationOptIn = @YES;
    }];

    UAScheduleAudience *requiresOptedOut = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder * _Nonnull builder) {
        builder.locationOptIn = @NO;
    }];

    [[[self.mockLocationProvider stub] andReturnValue:@YES] isLocationOptedIn];
    [[[self.mockLocationProvider stub] andReturnValue:@YES] isLocationUpdatesEnabled];

    // test
    XCTAssertFalse([UAScheduleAudienceChecks checkDisplayAudienceConditions:requiresOptedIn]);
    XCTAssertFalse([UAScheduleAudienceChecks checkDisplayAudienceConditions:requiresOptedOut]);
}

- (void)testLocationOptOut {
    // setup
    UAScheduleAudience *requiresOptedIn = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder * _Nonnull builder) {
        builder.locationOptIn = @YES;
    }];
    
    UAScheduleAudience *requiresOptedOut = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder * _Nonnull builder) {
        builder.locationOptIn = @NO;
    }];
    
    [[[self.mockLocationProvider stub] andReturnValue:@NO] isLocationOptedIn];
    [[[self.mockLocationProvider stub] andReturnValue:@YES] isLocationUpdatesEnabled];

    // test
    XCTAssertFalse([UAScheduleAudienceChecks checkDisplayAudienceConditions:requiresOptedIn]);
    XCTAssertTrue([UAScheduleAudienceChecks checkDisplayAudienceConditions:requiresOptedOut]);
}

- (void)testLocationOptOutWhenDataCollectionDisabled {
    self.isDataCollectionEnabled = NO;

    // setup
    UAScheduleAudience *requiresOptedIn = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder * _Nonnull builder) {
        builder.locationOptIn = @YES;
    }];

    UAScheduleAudience *requiresOptedOut = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder * _Nonnull builder) {
        builder.locationOptIn = @NO;
    }];

    [[[self.mockLocationProvider stub] andReturnValue:@NO] isLocationOptedIn];
    [[[self.mockLocationProvider stub] andReturnValue:@YES] isLocationUpdatesEnabled];

    // test
    XCTAssertFalse([UAScheduleAudienceChecks checkDisplayAudienceConditions:requiresOptedIn]);
    XCTAssertFalse([UAScheduleAudienceChecks checkDisplayAudienceConditions:requiresOptedOut]);
}

- (void)testNotificationOptIn {
    // setup
    UAScheduleAudience *requiresOptedIn = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder * _Nonnull builder) {
        builder.notificationsOptIn = @YES;
    }];
    
    UAScheduleAudience *requiresOptedOut = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder * _Nonnull builder) {
        builder.notificationsOptIn = @NO;
    }];
    
    [[[self.mockPush stub] andReturnValue:@YES] userPushNotificationsEnabled];
    [[[self.mockPush stub] andReturnValue:@(UAAuthorizedNotificationSettingsAlert)] authorizedNotificationSettings];

    // test
    XCTAssertTrue([UAScheduleAudienceChecks checkDisplayAudienceConditions:requiresOptedIn]);
    XCTAssertFalse([UAScheduleAudienceChecks checkDisplayAudienceConditions:requiresOptedOut]);
}

- (void)testNotificationOptInWhenDataCollectionDisabled {
    self.isDataCollectionEnabled = NO;

    // setup
    UAScheduleAudience *requiresOptedIn = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder * _Nonnull builder) {
        builder.notificationsOptIn = @YES;
    }];

    UAScheduleAudience *requiresOptedOut = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder * _Nonnull builder) {
        builder.notificationsOptIn = @NO;
    }];

    [[[self.mockPush stub] andReturnValue:@YES] userPushNotificationsEnabled];
    [[[self.mockPush stub] andReturnValue:@(UAAuthorizedNotificationSettingsAlert)] authorizedNotificationSettings];

    // test
    XCTAssertFalse([UAScheduleAudienceChecks checkDisplayAudienceConditions:requiresOptedIn]);
    XCTAssertFalse([UAScheduleAudienceChecks checkDisplayAudienceConditions:requiresOptedOut]);
}

- (void)testNotificationOptOut {
    // setup
    UAScheduleAudience *requiresOptedIn = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder * _Nonnull builder) {
        builder.notificationsOptIn = @YES;
    }];
    
    UAScheduleAudience *requiresOptedOut = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder * _Nonnull builder) {
        builder.notificationsOptIn = @NO;
    }];
    
    [[[self.mockPush stub] andReturnValue:@NO] userPushNotificationsEnabled];

    // test
    XCTAssertFalse([UAScheduleAudienceChecks checkDisplayAudienceConditions:requiresOptedIn]);
    XCTAssertTrue([UAScheduleAudienceChecks checkDisplayAudienceConditions:requiresOptedOut]);
}

- (void)testNotificationOptOutWhenDataCollectionDisabled {
    self.isDataCollectionEnabled = NO;

    // setup
    UAScheduleAudience *requiresOptedIn = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder * _Nonnull builder) {
        builder.notificationsOptIn = @YES;
    }];

    UAScheduleAudience *requiresOptedOut = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder * _Nonnull builder) {
        builder.notificationsOptIn = @NO;
    }];

    [[[self.mockPush stub] andReturnValue:@NO] userPushNotificationsEnabled];

    // test
    XCTAssertFalse([UAScheduleAudienceChecks checkDisplayAudienceConditions:requiresOptedIn]);
    XCTAssertFalse([UAScheduleAudienceChecks checkDisplayAudienceConditions:requiresOptedOut]);
}

- (void)testNewUser {
    // setup
    UAScheduleAudience *requiresNewUser = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder * _Nonnull builder) {
        builder.isNewUser = @YES;
    }];

    UAScheduleAudience *requiresExistingUser = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder * _Nonnull builder) {
        builder.isNewUser = @NO;
    }];

    // test
    XCTAssertFalse([UAScheduleAudienceChecks checkScheduleAudienceConditions:requiresNewUser isNewUser:NO]);
    XCTAssertTrue([UAScheduleAudienceChecks checkScheduleAudienceConditions:requiresExistingUser isNewUser:NO]);
    XCTAssertTrue([UAScheduleAudienceChecks checkScheduleAudienceConditions:requiresNewUser isNewUser:YES]);
    XCTAssertFalse([UAScheduleAudienceChecks checkScheduleAudienceConditions:requiresExistingUser isNewUser:YES]);
}

- (void)testTagSelector {
    // setup
    NSMutableArray<NSString *> *tags = [NSMutableArray array];
    
    [[[self.mockChannel stub] andDo:^(NSInvocation *invocation) {
        [invocation setReturnValue:(void *)&tags];
    }] tags];

    UAScheduleAudience *audience = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder * _Nonnull builder) {
        builder.tagSelector = [UATagSelector tag:@"expected tag"];
    }];
    
    // test
    XCTAssertFalse([UAScheduleAudienceChecks checkDisplayAudienceConditions:audience]);

    [tags addObject:@"expected tag"];
    XCTAssertTrue([UAScheduleAudienceChecks checkDisplayAudienceConditions:audience]);
}

- (void)testTagSelectorWhenDataCollectionDisabled {
    self.isDataCollectionEnabled = NO;

    // setup
    NSMutableArray<NSString *> *tags = [NSMutableArray array];

    [[[self.mockChannel stub] andDo:^(NSInvocation *invocation) {
        [invocation setReturnValue:(void *)&tags];
    }] tags];

    UAScheduleAudience *audience = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder * _Nonnull builder) {
        builder.tagSelector = [UATagSelector tag:@"expected tag"];
    }];

    // test
    XCTAssertFalse([UAScheduleAudienceChecks checkDisplayAudienceConditions:audience]);

    // Note: This is unlikely to occur in practice since tags are supposed to be cleared when dataCollectionEnabled changes to NO.
    // But it's an explicit code path in UAScheduleAudienceChecks, so we should test it anyway
    [tags addObject:@"expected tag"];
    XCTAssertFalse([UAScheduleAudienceChecks checkDisplayAudienceConditions:audience]);
}

- (void)testTestDevices {
    [[[self.mockChannel stub] andReturn:@"test channel"] identifier];

    UAScheduleAudience *audience = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder * _Nonnull builder) {
        builder.testDevices = @[@"obIvSbh47TjjqfCrPatbXQ==\n"]; // test channel
    }];

    XCTAssertTrue([UAScheduleAudienceChecks checkScheduleAudienceConditions:audience isNewUser:YES]);
}

- (void)testNotTestDevice {
    [[[self.mockChannel stub] andReturn:@"some other channel"] identifier];

    UAScheduleAudience *audience = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder * _Nonnull builder) {
        builder.testDevices = @[@"obIvSbh47TjjqfCrPatbXQ==\n"]; // test channel
    }];

    XCTAssertFalse([UAScheduleAudienceChecks checkScheduleAudienceConditions:audience isNewUser:YES]);
}

- (void)testLanguageAndVersion {
    // setup
    __block NSString *mockVersion;
    id mockApplicationMetrics = [self mockForClass:[UAApplicationMetrics class]];
    [[[mockApplicationMetrics stub] andDo:^(NSInvocation *invocation) {
        [invocation setReturnValue:(void *)&mockVersion];
    }] currentAppVersion];
    [[[self.mockAirship stub] andReturn:mockApplicationMetrics] applicationMetrics];

    UAScheduleAudience *requiresLangAndVersion = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder * _Nonnull builder) {
        builder.languageTags = @[@"en-US"];
        UAJSONMatcher *matcher = [UAJSONMatcher matcherWithValueMatcher:[UAJSONValueMatcher matcherWithVersionConstraint:@"1.0"] scope:@[@"ios",@"version"]];
        builder.versionPredicate = [UAJSONPredicate predicateWithJSONMatcher:matcher];
    }];

    // Unset mocked version
    XCTAssertFalse([UAScheduleAudienceChecks checkDisplayAudienceConditions:requiresLangAndVersion]);

    // Set mocked correct version
    mockVersion = @"1.0";
    XCTAssertTrue([UAScheduleAudienceChecks checkDisplayAudienceConditions:requiresLangAndVersion]);

    // Set mocked incorrect version
    mockVersion = @"2.0";
    XCTAssertFalse([UAScheduleAudienceChecks checkDisplayAudienceConditions:requiresLangAndVersion]);
}

- (void)testLanguageIDs {
    // tests
    UAScheduleAudience *audience = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder * _Nonnull builder) {
        builder.languageTags = @[@"en-US"];
    }];
    XCTAssertTrue([UAScheduleAudienceChecks checkDisplayAudienceConditions:audience]);

    audience = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder * _Nonnull builder) {
        builder.languageTags = @[@"fr_CA",@"en"];
    }];
    XCTAssertTrue([UAScheduleAudienceChecks checkDisplayAudienceConditions:audience]);
    
    audience = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder * _Nonnull builder) {
        builder.languageTags = @[@"fr",@"de-CH"];
    }];
    XCTAssertFalse([UAScheduleAudienceChecks checkDisplayAudienceConditions:audience]);
}

- (void)testAppVersion {
    // setup
    __block NSString *mockVersion;
    id mockApplicationMetrics = [self mockForClass:[UAApplicationMetrics class]];
    [[[mockApplicationMetrics stub] andDo:^(NSInvocation *invocation) {
        [invocation setReturnValue:(void *)&mockVersion];
    }] currentAppVersion];
    [[[self.mockAirship stub] andReturn:mockApplicationMetrics] applicationMetrics];
    
    UAScheduleAudience *audience = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder * _Nonnull builder) {
        UAJSONMatcher *matcher = [UAJSONMatcher matcherWithValueMatcher:[UAJSONValueMatcher matcherWithVersionConstraint:@"[1.0, 2.0]"] scope:@[@"ios",@"version"]];
        builder.versionPredicate = [UAJSONPredicate predicateWithJSONMatcher:matcher];
    }];
    
    // test
    mockVersion = @"1.0";
    XCTAssertTrue([UAScheduleAudienceChecks checkDisplayAudienceConditions:audience]);
    
    mockVersion = @"2";
    XCTAssertTrue([UAScheduleAudienceChecks checkDisplayAudienceConditions:audience]);
    
    mockVersion = @"3";
    XCTAssertFalse([UAScheduleAudienceChecks checkDisplayAudienceConditions:audience]);
}


@end
