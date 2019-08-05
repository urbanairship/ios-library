/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UAChannel+Internal.h"
#import "UAChannelRegistrar+Internal.h"
#import "UAChannelRegistrationPayload+Internal.h"
#import "UATestDispatcher.h"
#import "UAUtils+Internal.h"

@interface UAChannelTest : UABaseTest
@property(nonatomic, strong) id mockTagGroupsRegistrar;
@property(nonatomic, strong) id mockChannelRegistrar;
@property(nonatomic, strong) id mockPushProviderDelegate;
@property(nonatomic, strong) id mockUserProviderDelegate;
@property(nonatomic, strong) id mockUtils;
@property(nonatomic, strong) NSNotificationCenter *notificationCenter;
@property(nonatomic, strong) UAChannel *channel;
@property(nonatomic, strong) NSString *channelIDFromMockChannelRegistrar;
@property(nonatomic, strong) NSString *deviceToken;
@end

@implementation UAChannelTest

- (void)setUp {
    self.mockTagGroupsRegistrar = [self mockForClass:[UATagGroupsRegistrar class]];

    self.notificationCenter = [[NSNotificationCenter alloc] init];

    self.mockPushProviderDelegate = [self mockForProtocol:@protocol(UAPushProviderDelegate)];

    self.mockUserProviderDelegate = [self mockForProtocol:@protocol(UAUserProviderDelegate)];

    [[[self.mockUserProviderDelegate stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        void (^completionHandler)(UAUserData * _Nullable) = (__bridge void (^)(UAUserData * _Nullable))arg;
        completionHandler([UAUserData dataWithUsername:@"user" password:@"password" url:@"https://foo.bar.com"]);
    }] getUserData:OCMOCK_ANY dispatcher:OCMOCK_ANY];

    self.mockUtils = [self mockForClass:[UAUtils class]];

    [[[self.mockUtils stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        void (^completionHandler)(NSString *) = (__bridge void (^)(NSString *))arg;
        completionHandler(@"device");
    }] getDeviceID:OCMOCK_ANY dispatcher:OCMOCK_ANY];

    // Set up a mocked device api client
    self.mockChannelRegistrar = [self mockForClass:[UAChannelRegistrar class]];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.channel = [self createChannel];

    self.deviceToken = @"0123456789abcdef0123456789abcdef";

    // Simulate the channelID provided by the channel registrar
    OCMStub([self.mockChannelRegistrar channelID]).andDo(^(NSInvocation *invocation) {
        NSString *channelID;
        UA_LDEBUG(@"return self.channelIDFromMockChannelRegistrar = %@",self.channelIDFromMockChannelRegistrar);
        channelID = self.channelIDFromMockChannelRegistrar;
        [invocation setReturnValue:&channelID];
    });
}

- (UAChannel *)createChannel {
    UAChannel *channel = [UAChannel channelWithDataStore:self.dataStore
                                    config:self.config
                        notificationCenter:self.notificationCenter
                          channelRegistrar:self.mockChannelRegistrar
                        tagGroupsRegistrar:self.mockTagGroupsRegistrar];

    channel.pushProviderDelegate = self.mockPushProviderDelegate;
    channel.userProviderDelegate = self.mockUserProviderDelegate;

    return channel;
}

- (void)testTags {
    NSArray *tags = @[@"tag-one", @"tag-two"];
    self.channel.tags = tags;

    XCTAssertEqual((NSUInteger)2, self.channel.tags.count, @"should have added 2 tags");
    XCTAssertEqualObjects(tags, self.channel.tags, @"tags are not stored correctly");

    self.channel.tags = @[];
    XCTAssertEqual((NSUInteger)0, self.channel.tags.count, @"tags should return an empty array even when set to nil");

    XCTAssertEqual((NSUInteger)0, [[self.dataStore valueForKey:UAChannelTagsSettingsKey] count],
                   @"tags are not being cleared in standardUserDefaults");
}

/**
 * Tests tag setting when tag contains white space
 */
- (void)testSetTagsWhitespaceRemoval {
    NSArray *tags = @[@"   tag-one   ", @"tag-two   "];
    NSArray *tagsNoSpaces = @[@"tag-one", @"tag-two"];
    [self.channel setTags:tags];

    XCTAssertEqualObjects(tagsNoSpaces, self.channel.tags, @"whitespace was not trimmed from tags");
}

/**
 * Tests tag setting when tag consists entirely of whitespace
 */
- (void)testSetTagWhitespaceOnly {
    NSArray *tags = @[@" "];
    [self.channel setTags:tags];

    XCTAssertNotEqualObjects(tags, self.channel.tags, @"tag with whitespace only should not set");
}

/**
 * Tests tag setting when tag has minimum acceptable length
 */
- (void)testSetTagsMinTagSize {
    NSArray *tags = @[@"1"];
    [self.channel setTags:tags];

    XCTAssertEqualObjects(tags, self.channel.tags, @"tag with minimum character should set");
}

/**
 * Tests tag setting when tag has maximum acceptable length
 */
- (void)testSetTagsMaxTagSize {
    NSArray *tags = @[[@"" stringByPaddingToLength:127 withString: @"." startingAtIndex:0]];
    [self.channel setTags:tags];

    XCTAssertEqualObjects(tags, self.channel.tags, @"tag with maximum characters should set");
}

/**
 * Tests tag setting when tag has multi-byte characters
 */
- (void)testSetTagsMultiByteCharacters {
    NSArray *tags = @[@"함수 목록"];
    [self.channel setTags:tags];

    XCTAssertEqualObjects(tags, self.channel.tags, @"tag with multi-byte characters should set");
}

/**
 * Tests tag setting when tag has multi-byte characters and minimum length
 */
- (void)testMinLengthMultiByteCharacters {
    NSArray *tags = @[@"함"];
    [self.channel setTags:tags];

    XCTAssertEqualObjects(tags, self.channel.tags, @"tag with minimum multi-byte characters should set");
}

/**
 * Tests tag setting when tag has multi-byte characters and maximum length
 */
- (void)testMaxLengthMultiByteCharacters {
    NSArray *tags = @[[@"" stringByPaddingToLength:127 withString: @"함" startingAtIndex:0]];;
    [self.channel setTags:tags];

    XCTAssertEqualObjects(tags, self.channel.tags, @"tag with maximum multi-byte characters should set");
}

/**
 * Tests tag setting when tag has greater than maximum acceptable length
 */
- (void)testSetTagsOverMaxTagSizeRemoval {
    NSArray *tags = @[[@"" stringByPaddingToLength:128 withString: @"." startingAtIndex:0]];
    [self.channel setTags:tags];

    XCTAssertNotEqualObjects(tags, self.channel.tags, @"tag with 128 characters should not set");
}

- (void)testAddTagsToDeviceTagGroupWhenChannelTagRegistrationDisabled {
    // SETUP
    self.channel.channelTagRegistrationEnabled = YES;

    // EXPECTATIONS
    [[self.mockTagGroupsRegistrar reject] addTags:OCMOCK_ANY group:OCMOCK_ANY type:UATagGroupsTypeChannel];

    // TEST
    [self.channel addTags:@[@"tag1"] group:@"device"];

    // VERIFY
    [self.mockTagGroupsRegistrar verify];
}

- (void)testRemoveTagsFromDeviceTagGroupWhenChannelTagRegistrationDisabled {
    // SETUP
    self.channel.channelTagRegistrationEnabled = NO;
    [self.channel addTags:@[@"tag1"] group:@"device"];

    self.channel.channelTagRegistrationEnabled = YES;

    // EXPECTATIONS
    [[self.mockTagGroupsRegistrar reject] removeTags:OCMOCK_ANY group:OCMOCK_ANY type:UATagGroupsTypeChannel];

    // TEST
    [self.channel removeTags:@[@"tag1"] group:@"device"];

    // VERIFY
    [self.mockTagGroupsRegistrar verify];
}

- (void)testSetTagsInDeviceTagGroupWhenChannelTagRegistrationDisabled {
    // SETUP
    self.channel.channelTagRegistrationEnabled = YES;

    // EXPECTATIONS
    [[self.mockTagGroupsRegistrar reject] setTags:OCMOCK_ANY group:OCMOCK_ANY type:UATagGroupsTypeChannel];

    // TEST
    [self.channel setTags:@[@"tag1"] group:@"device"];

    // VERIFY
    [self.mockTagGroupsRegistrar verify];
}

- (void)testUpdateTags {
    // SETUP
    self.channelIDFromMockChannelRegistrar = @"someChannel";

    // EXPECTATIONS
    [[self.mockTagGroupsRegistrar expect] updateTagGroupsForID:[OCMArg checkWithBlock:^BOOL(id obj) {
        return (obj != nil);
    }] type:UATagGroupsTypeChannel];

    // TEST
    [self.channel updateChannelTagGroups];

    // VERIFY
    [self.mockTagGroupsRegistrar verify];
}

/**
 * Tests update registration when channel creation flag is disabled.
 */
- (void)testChannelCreationFlagDisabled {
    // Test when channel creation is disabled

    self.channel.channelCreationEnabled = NO;
    [[self.mockChannelRegistrar reject] registerForcefully:NO];

    [self.channel updateRegistration];

    XCTAssertNoThrow([self.mockChannelRegistrar verify]);
}

/**
 * Tests update registration when channel creation flag is enabled.
 */
- (void)testChannelCreationFlagEnabled {
    // Test when channel creation is enabled

    self.channel.channelCreationEnabled = YES;

    // Expect channel registrar to update its registration
    [[self.mockChannelRegistrar expect] registerForcefully:NO];

    [self.channel updateRegistration];

    XCTAssertNoThrow([self.mockChannelRegistrar verify], @"should update channel registration");
}

/**
 * Tests that registration updates when channel creation flag is enabled.
 */
- (void)testEnableChannelCreation {
    // Test when channel creation starts disabled
    self.channel.channelCreationEnabled = NO;

    [[self.mockChannelRegistrar expect] registerForcefully:NO];

    // TEST
    [self.channel enableChannelCreation];

    // VERIFY
    XCTAssertNoThrow([self.mockChannelRegistrar verify], @"should update channel registration");
}

/**
 * Tests enabling channel delay after channel ID has been registered.
 */
- (void)testEnableChannelDelayWithChannelID {
    // Set channelCreationDelayEnabled to NO
    self.config.channelCreationDelayEnabled = NO;

    // Init channel
    self.channel = [self createChannel];

    // Ensure channel creation enabled is YES
    XCTAssertTrue(self.channel.channelCreationEnabled);

    // Set channelCreationDelayEnabled to YES
    self.config.channelCreationDelayEnabled = YES;

    // Init channel
    self.channel = [self createChannel];

    // Ensure channel creation enabled is NO
    XCTAssertFalse(self.channel.channelCreationEnabled);

    // Have the channel registrar return a mocked identifier for channel init
    self.channelIDFromMockChannelRegistrar = @"someChannelID";

    self.channel = [self createChannel];

    // Ensure channel creation enabled is YES
    XCTAssertTrue(self.channel.channelCreationEnabled);
}

/**
 * Test registration payload when pushTokenRegistrationEnabled is NO does not include device token
 */
- (void)testRegistrationPayloadPushTokenRegistrationEnabledNo {
    [[[self.mockPushProviderDelegate stub] andReturnValue:@(NO)] pushTokenRegistrationEnabled];

    XCTestExpectation *createdPayload = [self expectationWithDescription:@"create payload"];

    [self.channel createChannelPayload:^(UAChannelRegistrationPayload * _Nonnull payload) {
        [createdPayload fulfill];
        XCTAssertNil(payload.pushAddress);
    } dispatcher:[UATestDispatcher testDispatcher]];

    [self waitForTestExpectations];
}

/**
 * Test registration payload include timezone, locale language, and country
 */
- (void)testRegistrationPayloadTimeZoneLocaleCountry {
    self.channel.channelTagRegistrationEnabled = YES;
    self.channel.tags = @[@"tag-one"];

    NSTimeZone *tz = [NSTimeZone timeZoneWithName:@"Pacific/Auckland"];

    [[[self.mockPushProviderDelegate stub] andReturnValue:@(YES)] isQuietTimeEnabled];
    [[[self.mockPushProviderDelegate stub] andReturn:tz] timeZone];

    XCTestExpectation *createdPayload = [self expectationWithDescription:@"create payload"];

    [self.channel createChannelPayload:^(UAChannelRegistrationPayload * _Nonnull payload) {
        [createdPayload fulfill];
        XCTAssertEqualObjects(payload.timeZone, tz.name);
        XCTAssertEqualObjects(payload.language, [[NSLocale autoupdatingCurrentLocale] objectForKey:NSLocaleLanguageCode]);
        XCTAssertEqualObjects(payload.country, [[NSLocale autoupdatingCurrentLocale] objectForKey:NSLocaleCountryCode]);

    } dispatcher:[UATestDispatcher testDispatcher]];

    [self waitForTestExpectations];
}

/**
 * Test that UserPushNotificationAllowed is NO
 */
- (void)testRegistrationPayloadNoDeviceToken {
    // Set up UAChannel and push provider delegate to give minimum payload
    [[[self.mockPushProviderDelegate stub] andReturnValue:@(NO)] pushTokenRegistrationEnabled];
    self.channel.channelTagRegistrationEnabled = NO;
    [[[self.mockPushProviderDelegate stub] andReturnValue:@(NO)] isAutobadgeEnabled];
    [[[self.mockPushProviderDelegate stub] andReturnValue:@(NO)] isQuietTimeEnabled];
    [[[self.mockPushProviderDelegate stub] andReturn:[NSTimeZone timeZoneWithName:@"Pacific/Auckland"]] timeZone];

    [[[self.mockPushProviderDelegate stub] andReturnValue:@(NO)] userPushNotificationsAllowed];

    // Verify opt in is false when device token is nil
    UAChannelRegistrationPayload *expectedPayload = [[UAChannelRegistrationPayload alloc] init];
    expectedPayload.deviceID = @"device";
    expectedPayload.userID = @"user";
    expectedPayload.optedIn = false;
    expectedPayload.setTags = NO;
    expectedPayload.language =  [[NSLocale autoupdatingCurrentLocale] objectForKey:NSLocaleLanguageCode];
    expectedPayload.country =  [[NSLocale autoupdatingCurrentLocale] objectForKey:NSLocaleCountryCode];
    expectedPayload.timeZone = @"Pacific/Auckland";

    XCTestExpectation *createdPayload = [self expectationWithDescription:@"create payload"];

    [self.channel createChannelPayload:^(UAChannelRegistrationPayload * _Nonnull payload) {
        [createdPayload fulfill];
        XCTAssertEqualObjects(payload, expectedPayload);
    } dispatcher:[UATestDispatcher testDispatcher]];

    [self waitForTestExpectations];
}

- (void)testRegistrationPayloadDeviceTagsDisabled {
    [[[self.mockPushProviderDelegate stub] andReturnValue:@(YES)] userPushNotificationsAllowed];
    self.channel.channelTagRegistrationEnabled = NO;
    self.channel.tags = @[@"tag-one"];

    XCTestExpectation *createdPayload = [self expectationWithDescription:@"create payload"];

    [self.channel createChannelPayload:^(UAChannelRegistrationPayload * _Nonnull payload) {
        [createdPayload fulfill];
        XCTAssertNil(payload.tags);
    } dispatcher:[UATestDispatcher testDispatcher]];

    [self waitForTestExpectations];
}

- (void)testRegistrationPayloadAutoBadgeEnabled {
    [[[self.mockPushProviderDelegate stub] andReturnValue:@(YES)] userPushNotificationsAllowed];
    [[[self.mockPushProviderDelegate stub] andReturnValue:@(YES)] isAutobadgeEnabled];
    [[[self.mockPushProviderDelegate stub] andReturnValue:@(30)] badgeNumber];

    XCTestExpectation *createdPayload = [self expectationWithDescription:@"create payload"];

    [self.channel createChannelPayload:^(UAChannelRegistrationPayload * _Nonnull payload) {
        [createdPayload fulfill];
        XCTAssertEqualObjects(payload.badge, @(30));
    } dispatcher:[UATestDispatcher testDispatcher]];

    [self waitForTestExpectations];
}

- (void)testRegistrationPayloadNoQuietTime {
    [[[self.mockPushProviderDelegate stub] andReturnValue:@(YES)] userPushNotificationsAllowed];
    [[[self.mockPushProviderDelegate stub] andReturnValue:@(NO)] isQuietTimeEnabled];

    XCTestExpectation *createdPayload = [self expectationWithDescription:@"create payload"];

    [self.channel createChannelPayload:^(UAChannelRegistrationPayload * _Nonnull payload) {
        [createdPayload fulfill];
        XCTAssertNil(payload.quietTime);
    } dispatcher:[UATestDispatcher testDispatcher]];

    [self waitForTestExpectations];
}
/**
 * Test applicationDidBecomeActive, when run after app was backgrounded, does register
 */
- (void)testApplicationDidBecomeActiveAfterBackgrounding {
    // SETUP
    self.channel.isForegrounded = NO;

    [self.dataStore setBool:YES forKey:UAChannelCreationOnForeground];

    // Expect UAChannel to update channel registration
    [[self.mockChannelRegistrar expect] registerForcefully:NO];

    // TEST
    [self.channel applicationDidBecomeActive];

    // VERIFY
    XCTAssertNoThrow([self.mockChannelRegistrar verify], @"should update channel registration");
}

/**
 * Test applicationDidEnterBackground clears the notification and sets
 * the hasEnteredBackground flag
 */
- (void)testApplicationDidEnterBackground {
    [self.channel applicationDidEnterBackground];

    XCTAssertTrue([self.dataStore boolForKey:UAChannelCreationOnForeground], @"applicationDidEnterBackground should set channelCreationOnForeground to true");
}

/**
 * Test update registration is called when the device enters a background and
 * we do not have a channel ID
 */
- (void)testApplicationDidEnterBackgroundCreatesChannel {
    // Expect UAChannel to update channel registration
    [[self.mockChannelRegistrar expect] registerForcefully:NO];

    [self.channel applicationDidEnterBackground];

    XCTAssertNoThrow([self.mockChannelRegistrar verify], @"Channel registration should be called");
}

/**
 * Test existing channel created posts an NSNotification
 */
- (void)testExistingChannelCreatedNSNotification {
    id expectedUserInfo = @{ UAChannelCreatedEventExistingKey: @(YES),
                             UAChannelCreatedEventChannelKey:@"someChannelID" };

    __block NSNotification *notification;

    XCTestExpectation *notificationFired = [self expectationWithDescription:@"Notification event fired"];
    [self.notificationCenter addObserverForName:UAChannelCreatedEvent object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        notification = note;
        [notificationFired fulfill];
    }];

    [self.channel channelCreated:@"someChannelID" existing:YES];

    [self waitForTestExpectations];
    XCTAssertEqualObjects(expectedUserInfo, notification.userInfo);
}

/**
 * Test new channel created posts an NSNotification of type UAChannelCreatedEvent
 */
- (void)testNewChannelCreatedNSNotification {
    id expectedUserInfo = @{ UAChannelCreatedEventExistingKey: @(NO),
                             UAChannelCreatedEventChannelKey:@"someChannelID" };


    __block NSNotification *notification;

    XCTestExpectation *notificationFired = [self expectationWithDescription:@"Notification event fired"];
    [self.notificationCenter addObserverForName:UAChannelCreatedEvent object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        notification = note;
        [notificationFired fulfill];
    }];

    [self.channel channelCreated:@"someChannelID" existing:NO];

    [self waitForTestExpectations];
    XCTAssertEqualObjects(expectedUserInfo, notification.userInfo);
}

/**
 * Test channel updated posts an NSNotification of type UAChannelUpdatedEvent
 */
- (void)testChannelUpdatedNSNotification {
    self.channelIDFromMockChannelRegistrar = @"someChannelID";

    XCTestExpectation *notificationFired = [self expectationWithDescription:@"Notification event fired"];
    [self.notificationCenter addObserverForName:UAChannelUpdatedEvent object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        [notificationFired fulfill];
    }];

    [self.channel registrationSucceeded];

    [self waitForTestExpectations];
}

@end
