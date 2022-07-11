/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UAScheduleAudienceChecks+Internal.h"
#import "UAScheduleAudience+Internal.h"
#import "UATagSelector.h"
#import "AirshipTests-Swift.h"

@import AirshipCore;

@interface UAScheduleAudienceChecksTest : UAAirshipBaseTest

@property(nonatomic, strong) UATestAirshipInstance *airship;
@property (nonatomic, strong) id mockLocationProvider;
@property (nonatomic, strong) id mockPush;
@property (nonatomic, strong) id mockChannel;
@property (nonatomic, strong) id mockApplicationMetrics;
@property (nonatomic, strong) UAPermissionsManager *permissionManager;
@property (nonatomic, strong) UAPrivacyManager *privacyManager;
@end

@implementation UAScheduleAudienceChecksTest

- (void)setUp {
    [super setUp];

    self.mockPush = [self mockForClass:[UAPush class]];
    self.mockChannel = [self mockForClass:[UAChannel class]];
    self.mockLocationProvider = [self mockForProtocol:@protocol(UALocationProvider)];
    self.mockApplicationMetrics = [self mockForClass:[UAApplicationMetrics class]];
    
    self.privacyManager = [[UAPrivacyManager alloc] initWithDataStore:self.dataStore
                                               defaultEnabledFeatures:UAFeaturesAll];
    self.permissionManager = [[UAPermissionsManager alloc] init];

    self.airship = [[UATestAirshipInstance alloc] init];
    self.airship.components = @[self.mockPush, self.mockChannel];
    self.airship.privacyManager = self.privacyManager;
    self.airship.locationProvider = self.mockLocationProvider;
    self.airship.applicationMetrics = self.mockApplicationMetrics;
    self.airship.permissionsManager = self.permissionManager;
    [self.airship makeShared];
}

- (void)testEmptyAudience {
    UAScheduleAudience *audience = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder * _Nonnull builder) {
    }];
    
    [UAScheduleAudienceChecks checkDisplayAudienceConditions:audience completionHandler:^(BOOL result) {
        XCTAssertTrue(result);
    }];
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
    [UAScheduleAudienceChecks checkDisplayAudienceConditions:requiresOptedIn completionHandler:^(BOOL result) {
        XCTAssertTrue(result);
    }];
    [UAScheduleAudienceChecks checkDisplayAudienceConditions:requiresOptedOut completionHandler:^(BOOL result) {
        XCTAssertFalse(result);
    }];
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
    [UAScheduleAudienceChecks checkDisplayAudienceConditions:requiresOptedIn completionHandler:^(BOOL result) {
        XCTAssertFalse(result);
    }];
    [UAScheduleAudienceChecks checkDisplayAudienceConditions:requiresOptedOut completionHandler:^(BOOL result) {
        XCTAssertTrue(result);
    }];
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
    [UAScheduleAudienceChecks checkDisplayAudienceConditions:requiresOptedIn completionHandler:^(BOOL result) {
        XCTAssertTrue(result);
    }];
    [UAScheduleAudienceChecks checkDisplayAudienceConditions:requiresOptedOut completionHandler:^(BOOL result) {
        XCTAssertFalse(result);
    }];
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
    [UAScheduleAudienceChecks checkDisplayAudienceConditions:requiresOptedIn completionHandler:^(BOOL result) {
        XCTAssertFalse(result);
    }];
    [UAScheduleAudienceChecks checkDisplayAudienceConditions:requiresOptedOut completionHandler:^(BOOL result) {
        XCTAssertTrue(result);
    }];
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
    [UAScheduleAudienceChecks checkDisplayAudienceConditions:audience completionHandler:^(BOOL result) {
        XCTAssertFalse(result);
    }];

    [tags addObject:@"expected tag"];
    [UAScheduleAudienceChecks checkDisplayAudienceConditions:audience completionHandler:^(BOOL result) {
        XCTAssertTrue(result);
    }];
}

- (void)testTagSelectorWhenTagsDisabled {
    [self.privacyManager disableFeatures:UAFeaturesTagsAndAttributes];

    // setup
    NSMutableArray<NSString *> *tags = [NSMutableArray array];

    [[[self.mockChannel stub] andDo:^(NSInvocation *invocation) {
        [invocation setReturnValue:(void *)&tags];
    }] tags];

    UAScheduleAudience *audience = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder * _Nonnull builder) {
        builder.tagSelector = [UATagSelector tag:@"expected tag"];
    }];

    // test
    [UAScheduleAudienceChecks checkDisplayAudienceConditions:audience completionHandler:^(BOOL result) {
        XCTAssertFalse(result);
    }];

    // Note: This is unlikely to occur in practice since tags are supposed to be cleared when dataCollectionEnabled changes to NO.
    // But it's an explicit code path in UAScheduleAudienceChecks, so we should test it anyway
    [tags addObject:@"expected tag"];
    [UAScheduleAudienceChecks checkDisplayAudienceConditions:audience completionHandler:^(BOOL result) {
        XCTAssertFalse(result);
    }];
}

- (void)testTestDevices {
    [[[self.mockChannel stub] andReturn:@"test channel"] identifier];

    UAScheduleAudience *audience = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder * _Nonnull builder) {
        builder.testDevices = @[@"obIvSbh47TjjqfCrPatbXQ==\n"]; // test channel
    }];

    XCTAssertTrue([UAScheduleAudienceChecks checkScheduleAudienceConditions:audience isNewUser:YES]);
    [UAScheduleAudienceChecks checkDisplayAudienceConditions:audience completionHandler:^(BOOL result) {
        XCTAssertTrue(result);
    }];
}

- (void)testNotTestDevice {
    [[[self.mockChannel stub] andReturn:@"some other channel"] identifier];

    UAScheduleAudience *audience = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder * _Nonnull builder) {
        builder.testDevices = @[@"obIvSbh47TjjqfCrPatbXQ==\n"]; // test channel
    }];

    XCTAssertFalse([UAScheduleAudienceChecks checkScheduleAudienceConditions:audience isNewUser:YES]);
    [UAScheduleAudienceChecks checkDisplayAudienceConditions:audience completionHandler:^(BOOL result) {
        XCTAssertFalse(result);
    }];
}

- (void)testLanguageAndVersion {
    // setup
    __block NSString *mockVersion;
    [[[self.mockApplicationMetrics stub] andDo:^(NSInvocation *invocation) {
        [invocation setReturnValue:(void *)&mockVersion];
    }] currentAppVersion];

    UAScheduleAudience *requiresLangAndVersion = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder * _Nonnull builder) {
        builder.languageTags = @[@"en-US"];
        UAJSONMatcher *matcher = [[UAJSONMatcher alloc] initWithValueMatcher:[UAJSONValueMatcher matcherWithVersionConstraint:@"1.0"] scope:@[@"ios",@"version"]];
        builder.versionPredicate = [[UAJSONPredicate alloc] initWithJSONMatcher:matcher];
    }];

    // Unset mocked version
    [UAScheduleAudienceChecks checkDisplayAudienceConditions:requiresLangAndVersion completionHandler:^(BOOL result) {
        XCTAssertFalse(result);
    }];

    // Set mocked correct version
    mockVersion = @"1.0";
    [UAScheduleAudienceChecks checkDisplayAudienceConditions:requiresLangAndVersion completionHandler:^(BOOL result) {
        XCTAssertTrue(result);
    }];

    // Set mocked incorrect version
    mockVersion = @"2.0";
    [UAScheduleAudienceChecks checkDisplayAudienceConditions:requiresLangAndVersion completionHandler:^(BOOL result) {
        XCTAssertFalse(result);
    }];
}

- (void)testLanguageIDs {
    // tests
    UAScheduleAudience *audience = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder * _Nonnull builder) {
        builder.languageTags = @[@"en-US"];
    }];
    [UAScheduleAudienceChecks checkDisplayAudienceConditions:audience completionHandler:^(BOOL result) {
        XCTAssertTrue(result);
    }];

    audience = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder * _Nonnull builder) {
        builder.languageTags = @[@"fr_CA",@"en"];
    }];
    [UAScheduleAudienceChecks checkDisplayAudienceConditions:audience completionHandler:^(BOOL result) {
        XCTAssertTrue(result);
    }];
    
    audience = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder * _Nonnull builder) {
        builder.languageTags = @[@"fr",@"de-CH"];
    }];
    [UAScheduleAudienceChecks checkDisplayAudienceConditions:audience completionHandler:^(BOOL result) {
        XCTAssertFalse(result);
    }];
}

- (void)testAppVersion {
    __block NSString *mockVersion;
    [[[self.mockApplicationMetrics stub] andDo:^(NSInvocation *invocation) {
        [invocation setReturnValue:(void *)&mockVersion];
    }] currentAppVersion];

    UAScheduleAudience *audience = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder * _Nonnull builder) {
        UAJSONMatcher *matcher = [[UAJSONMatcher alloc] initWithValueMatcher:[UAJSONValueMatcher matcherWithVersionConstraint:@"[1.0, 2.0]"] scope:@[@"ios",@"version"]];
        builder.versionPredicate = [[UAJSONPredicate alloc] initWithJSONMatcher:matcher];
    }];
    
    // test
    mockVersion = @"1.0";
    [UAScheduleAudienceChecks checkDisplayAudienceConditions:audience completionHandler:^(BOOL result) {
        XCTAssertTrue(result);
    }];
    
    mockVersion = @"2";
    [UAScheduleAudienceChecks checkDisplayAudienceConditions:audience completionHandler:^(BOOL result) {
        XCTAssertTrue(result);
    }];
    
    mockVersion = @"3";
    [UAScheduleAudienceChecks checkDisplayAudienceConditions:audience completionHandler:^(BOOL result) {
        XCTAssertFalse(result);
    }];
}

- (void)testRequiresAnalytics {
    // setup
    UAScheduleAudience *requiresAnalyticsEnabled = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder * _Nonnull builder) {
        builder.requiresAnalytics = @YES;
    }];
    
    UAScheduleAudience *requiresAnalyticsDisabled = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder * _Nonnull builder) {
        builder.requiresAnalytics = @NO;
    }];

    //Enable privacy manager analytics
    [[UAirship shared].privacyManager enableFeatures:UAFeaturesAnalytics];

    // test
    [UAScheduleAudienceChecks checkDisplayAudienceConditions:requiresAnalyticsEnabled completionHandler:^(BOOL result) {
        XCTAssertTrue(result);
    }];
    [UAScheduleAudienceChecks checkDisplayAudienceConditions:requiresAnalyticsDisabled completionHandler:^(BOOL result) {
        XCTAssertTrue(result);
    }];
    
    //Disable privacy manager analytics
    [[UAirship shared].privacyManager disableFeatures:UAFeaturesAnalytics];
    
    // test
    [UAScheduleAudienceChecks checkDisplayAudienceConditions:requiresAnalyticsEnabled completionHandler:^(BOOL result) {
        XCTAssertFalse(result);
    }];
    [UAScheduleAudienceChecks checkDisplayAudienceConditions:requiresAnalyticsDisabled completionHandler:^(BOOL result) {
        XCTAssertTrue(result);
    }];
}

- (void)testPermissions {
    
    UAScheduleAudience *audience = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder * _Nonnull builder) {
        UAJSONMatcher *notificationMatcher = [[UAJSONMatcher alloc] initWithValueMatcher:[UAJSONValueMatcher matcherWhereStringEquals:@"granted"] key:@"display_notifications"];
        UAJSONMatcher *locationMatcher = [[UAJSONMatcher alloc] initWithValueMatcher:[UAJSONValueMatcher matcherWhereStringEquals:@"denied"] key:@"location"];
        UAJSONPredicate *notificationPredicate = [[UAJSONPredicate alloc] initWithJSONMatcher:notificationMatcher];
        UAJSONPredicate *locationPredicate = [[UAJSONPredicate alloc] initWithJSONMatcher:locationMatcher];
        UAJSONPredicate *predicate = [UAJSONPredicate andPredicateWithSubpredicates:@[notificationPredicate, locationPredicate]];
        XCTAssertNotNil(predicate);
        
        builder.permissionPredicate = predicate;
    }];
    
    TestPermissionsDelegate *notificationDelegate = [[TestPermissionsDelegate alloc] init];
    TestPermissionsDelegate *locationDelgate = [[TestPermissionsDelegate alloc] init];
    
    //audience = @{@"post_notifications":@"denied"}
    [self.permissionManager setDelegate:notificationDelegate permission:UAPermissionDisplayNotifications];
    notificationDelegate.permissionStatus = UAPermissionStatusDenied;
    [UAScheduleAudienceChecks checkDisplayAudienceConditions:audience completionHandler:^(BOOL result) {
        XCTAssertFalse(result);
    }];
    
    //audience = @{@"post_notifications": @"granted"}
    [self.permissionManager setDelegate:notificationDelegate permission:UAPermissionLocation];
    notificationDelegate.permissionStatus = UAPermissionStatusGranted;
    [UAScheduleAudienceChecks checkDisplayAudienceConditions:audience completionHandler:^(BOOL result) {
        XCTAssertFalse(result);
    }];

    //audience = @{@"post_notifications":@"granted", @"location":"denied"}
    [self.permissionManager setDelegate:notificationDelegate permission:UAPermissionDisplayNotifications];
    notificationDelegate.permissionStatus = UAPermissionStatusGranted;
    [self.permissionManager setDelegate:locationDelgate permission:UAPermissionLocation];
    locationDelgate.permissionStatus = UAPermissionStatusDenied;
    [UAScheduleAudienceChecks checkDisplayAudienceConditions:audience completionHandler:^(BOOL result) {
        XCTAssertTrue(result);
    }];
}

@end
