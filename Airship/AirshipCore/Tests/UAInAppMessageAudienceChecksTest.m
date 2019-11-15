/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UAInAppMessageAudienceChecks+Internal.h"
#import "UAInAppMessageAudience+Internal.h"
#import "UAVersionMatcher.h"
#import "UAirship+Internal.h"
#import "UAPush+Internal.h"
#import "UAInAppMessageTagSelector.h"
#import "UAApplicationMetrics.h"
#import "UAJSONPredicate.h"

@interface UAInAppMessageAudienceChecksTest : UABaseTest

@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) id mockLocationProviderDelegate;
@property (nonatomic, strong) id mockPush;
@property (nonatomic, strong) id mockChannel;

@end

@implementation UAInAppMessageAudienceChecksTest

- (void)setUp {
    [super setUp];

    self.mockAirship = [self mockForClass:[UAirship class]];
    self.mockPush = [self mockForClass:[UAPush class]];
    self.mockChannel = [self mockForClass:[UAChannel class]];

    [[[self.mockAirship stub] andReturn:self.mockPush] sharedPush];
    [[[self.mockAirship stub] andReturn:self.mockChannel] sharedChannel];

    [UAirship setSharedAirship:self.mockAirship];

    self.mockLocationProviderDelegate = [self mockForProtocol:@protocol(UALocationProviderDelegate)];
    [[[self.mockAirship stub] andReturn:self.mockLocationProviderDelegate] locationProviderDelegate];
}

- (void)testEmptyAudience {
    UAInAppMessageAudience *audience = [UAInAppMessageAudience audienceWithBuilderBlock:^(UAInAppMessageAudienceBuilder * _Nonnull builder) {
    }];
    
    XCTAssertTrue([UAInAppMessageAudienceChecks checkDisplayAudienceConditions:audience]);
}

- (void)testLocationOptIn {
    // setup
    UAInAppMessageAudience *requiresOptedIn = [UAInAppMessageAudience audienceWithBuilderBlock:^(UAInAppMessageAudienceBuilder * _Nonnull builder) {
        builder.locationOptIn = @YES;
    }];
    
    UAInAppMessageAudience *requiresOptedOut = [UAInAppMessageAudience audienceWithBuilderBlock:^(UAInAppMessageAudienceBuilder * _Nonnull builder) {
        builder.locationOptIn = @NO;
    }];
    
    [[[self.mockLocationProviderDelegate stub] andReturnValue:@YES] isLocationOptedIn];
    [[[self.mockLocationProviderDelegate stub] andReturnValue:@YES] isLocationUpdatesEnabled];

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
    
    [[[self.mockLocationProviderDelegate stub] andReturnValue:@NO] isLocationOptedIn];
    [[[self.mockLocationProviderDelegate stub] andReturnValue:@YES] isLocationUpdatesEnabled];

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
    
    [[[self.mockPush stub] andReturnValue:@YES] userPushNotificationsEnabled];
    [[[self.mockPush stub] andReturnValue:@(UAAuthorizedNotificationSettingsAlert)] authorizedNotificationSettings];

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
    
    [[[self.mockPush stub] andReturnValue:@NO] userPushNotificationsEnabled];

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
    
    [[[self.mockChannel stub] andDo:^(NSInvocation *invocation) {
        [invocation setReturnValue:(void *)&tags];
    }] tags];

    UAInAppMessageAudience *audience = [UAInAppMessageAudience audienceWithBuilderBlock:^(UAInAppMessageAudienceBuilder * _Nonnull builder) {
        builder.tagSelector = [UAInAppMessageTagSelector tag:@"expected tag"];
    }];
    
    // test
    XCTAssertFalse([UAInAppMessageAudienceChecks checkDisplayAudienceConditions:audience]);

    [tags addObject:@"expected tag"];
    XCTAssertTrue([UAInAppMessageAudienceChecks checkDisplayAudienceConditions:audience]);
}


- (void)testTestDevices {
    [[[self.mockChannel stub] andReturn:@"test channel"] identifier];

    UAInAppMessageAudience *audience = [UAInAppMessageAudience audienceWithBuilderBlock:^(UAInAppMessageAudienceBuilder * _Nonnull builder) {
        builder.testDevices = @[@"obIvSbh47TjjqfCrPatbXQ==\n"]; // test channel
    }];

    XCTAssertTrue([UAInAppMessageAudienceChecks checkScheduleAudienceConditions:audience isNewUser:YES]);
}

- (void)testNotTestDevice {
    [[[self.mockChannel stub] andReturn:@"some other channel"] identifier];

    UAInAppMessageAudience *audience = [UAInAppMessageAudience audienceWithBuilderBlock:^(UAInAppMessageAudienceBuilder * _Nonnull builder) {
        builder.testDevices = @[@"obIvSbh47TjjqfCrPatbXQ==\n"]; // test channel
    }];

    XCTAssertFalse([UAInAppMessageAudienceChecks checkScheduleAudienceConditions:audience isNewUser:YES]);
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
        UAJSONMatcher *matcher = [UAJSONMatcher matcherWithValueMatcher:[UAJSONValueMatcher matcherWithVersionConstraint:@"[1.0, 2.0]"] scope:@[@"ios",@"version"]];
        builder.versionPredicate = [UAJSONPredicate predicateWithJSONMatcher:matcher];
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
