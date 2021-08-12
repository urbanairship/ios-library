/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UAChannel+Internal.h"
#import "UAChannelRegistrationPayload+Internal.h"
#import "UAUtils+Internal.h"
#import "UAUserData+Internal.h"
#import "UAActionResult.h"
#import "UAirship+Internal.h"
#import "UAAppIntegration+Internal.h"
#import "UAPush+Internal.h"
#import "AirshipTests-Swift.h"

@import AirshipCore;

static NSString * const UAChannelTagUpdateTaskID = @"UAChannel.tags.update";
static NSString * const UAChannelAttributeUpdateTaskID = @"UAChannel.attributes.update";

@interface UAChannel()
- (void)onEnabledFeaturesChanged;
@end

@interface UAChannelTest : UAAirshipBaseTest
@property(nonatomic, strong) id mockChannelRegistrar;
@property(nonatomic, strong) id mockLocaleManager;
@property(nonatomic, strong) id mockTimeZone;
@property(nonatomic, strong) NSNotificationCenter *notificationCenter;
@property(nonatomic, strong) UAChannel *channel;
@property(nonatomic, strong) UAPrivacyManager *privacyManager;
@property(nonatomic, copy) NSString *channelIDFromMockChannelRegistrar;
@property(nonatomic, copy) NSString *deviceToken;
@property(nonatomic, strong) UATestDate *testDate;
@property (nonatomic, strong) id mockAudienceManager;
@end

@interface UAChannel() <UAChannelRegistrarDelegate>
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@end

@implementation UAChannelTest

- (void)setUp {
    [super setUp];

    self.notificationCenter = [[NSNotificationCenter alloc] init];

    self.mockTimeZone = [self mockForClass:[NSTimeZone class]];
    [[[self.mockTimeZone stub] andReturn:self.mockTimeZone] defaultTimeZone];

    self.notificationCenter = [[NSNotificationCenter alloc] init];

    // Set up a mocked device api client
    self.mockChannelRegistrar = [self mockForClass:[UAChannelRegistrar class]];

    self.mockLocaleManager = [self mockForClass:[UALocaleManager class]];
    [[[self.mockLocaleManager stub] andReturn:[NSLocale autoupdatingCurrentLocale]] currentLocale];

    self.testDate = [[UATestDate alloc] initWithOffset:0 dateOverride:[NSDate date]];

    self.privacyManager = [[UAPrivacyManager alloc] initWithDataStore:self.dataStore defaultEnabledFeatures:UAFeaturesAll];

    self.mockAudienceManager = [self mockForClass:[UAChannelAudienceManager class]];
    
    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.channel = [self createChannel];

    // Simulate the channelID provided by the channel registrar
    OCMStub([self.mockChannelRegistrar channelID]).andDo(^(NSInvocation *invocation) {
        NSString *channelID;
        UA_LDEBUG(@"return self.channelIDFromMockChannelRegistrar = %@",self.channelIDFromMockChannelRegistrar);
        channelID = self.channelIDFromMockChannelRegistrar;
        [invocation setReturnValue:&channelID];
    });
}

- (void)tearDown {
    [self.mockTimeZone stopMocking];
    [super tearDown];
}

- (UAChannel *)createChannel {
    UAChannel *channel = [UAChannel channelWithDataStore:self.dataStore
                                                  config:self.config
                                      notificationCenter:self.notificationCenter
                                        channelRegistrar:self.mockChannelRegistrar
                                         audienceManager:self.mockAudienceManager
                                           localeManager:self.mockLocaleManager
                                                    date:self.testDate
                                          privacyManager:self.privacyManager];

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
    NSArray *tags = @[[@"" stringByPaddingToLength:128 withString: @"함" startingAtIndex:0]];;
    [self.channel setTags:tags];

    XCTAssertEqualObjects(tags, self.channel.tags, @"tag with maximum multi-byte characters should set");
}

/**
 * Tests tag setting when tag has greater than maximum acceptable length
 */
- (void)testSetTagsOverMaxTagSizeRemoval {
    NSArray *tags = @[[@"" stringByPaddingToLength:129 withString: @"." startingAtIndex:0]];
    [self.channel setTags:tags];

    XCTAssertNotEqualObjects(tags, self.channel.tags, @"tag with 128 characters should not set");
}

- (void)testSetTagsWhenDataCollectionDisabled {
    // SETUP
    self.channel.tags = @[];
    [self.privacyManager disableFeatures:UAFeaturesTagsAndAttributes];

    // TEST
    self.channel.tags = @[@"haha", @"no"];

    // VERIFY
    XCTAssertEqualObjects(self.channel.tags, @[]);
}

- (void)testAddTagsWhenDataCollectionDisabled {
    // SETUP
    self.channel.tags = @[];
    [self.privacyManager disableFeatures:UAFeaturesTagsAndAttributes];


    // TEST
    [self.channel addTags:@[@"haha", @"no"]];

    // VERIFY
    XCTAssertEqualObjects(self.channel.tags, @[]);
}

- (void)testAddTagWhenDataCollectionDisabled {
    // SETUP
    self.channel.tags = @[];
    [self.privacyManager disableFeatures:UAFeaturesTagsAndAttributes];

    // TEST
    [self.channel addTag:@"nope"];

    // VERIFY
    XCTAssertEqualObjects(self.channel.tags, @[]);
}

- (void)testRemoveTagsWhenDataCollectionDisabled {
    // SETUP
    NSArray *tags = @[@"this_shouldn't", @"happen"];
    self.channel.tags = tags;
    [self.privacyManager disableFeatures:UAFeaturesTagsAndAttributes];

    // TEST
    [self.channel removeTags:tags];

    // VERIFY
    XCTAssertEqualObjects(self.channel.tags, tags);
}

- (void)testRemoveTagWhenDataCollectionDisabled {
    // SETUP
    self.channel.tags = @[@"this_shouldn't_happen"];
    [self.privacyManager disableFeatures:UAFeaturesTagsAndAttributes];

    // TEST
    [self.channel removeTag:@"this_shouldn't_happen"];

    // VERIFY
    XCTAssertEqualObjects(self.channel.tags, @[@"this_shouldn't_happen"]);
}

- (void)testDataCollectionDisabledClearsTags {
    self.channel.tags = @[@"cool", @"rad"];

    [self.privacyManager disableFeatures:UAFeaturesTagsAndAttributes];
    [self.channel onEnabledFeaturesChanged];

    XCTAssertEqualObjects(self.channel.tags, @[]);
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
 * Test channel registration payload.
 */
- (void)testRegistrationPayload {
    self.channel.channelTagRegistrationEnabled = YES;
    [self.privacyManager enableFeatures:UAFeaturesTagsAndAttributes];

    self.channel.tags = @[@"cool", @"story"];
    [[[self.mockTimeZone stub] andReturn:@"cool zone"] name];

    UAChannelRegistrationPayload *expectedPayload = [[UAChannelRegistrationPayload alloc] init];
    expectedPayload.language = [[NSLocale autoupdatingCurrentLocale] objectForKey:NSLocaleLanguageCode];
    expectedPayload.country = [[NSLocale autoupdatingCurrentLocale] objectForKey:NSLocaleCountryCode];
    expectedPayload.timeZone = @"cool zone";
    expectedPayload.tags = @[@"cool", @"story"];
    expectedPayload.setTags = YES;
    expectedPayload.appVersion = [UAUtils bundleShortVersionString];
    expectedPayload.SDKVersion = [UAirshipVersion get];
    expectedPayload.deviceOS = [UIDevice currentDevice].systemVersion;
    expectedPayload.deviceModel = [UAUtils deviceModelName];
    expectedPayload.carrier = [UAUtils carrierName];

    XCTestExpectation *createdPayload = [self expectationWithDescription:@"create payload"];

    [self.channel createChannelPayloadWithCompletionHandler:^(UAChannelRegistrationPayload * _Nonnull payload) {
        XCTAssertEqualObjects(payload, expectedPayload);
        [createdPayload fulfill];
    }];

    [self waitForTestExpectations];
}

/**
 * Test channel registration payload when channel tag registration is disabled.
 */
- (void)testRegistrationPayloadChannelTagRegistrationDisabled {
    self.channel.channelTagRegistrationEnabled = NO;
    [self.privacyManager enableFeatures:UAFeaturesTagsAndAttributes];

    self.channel.tags = @[@"cool", @"story"];
    [[[self.mockTimeZone stub] andReturn:@"cool zone"] name];

    UAChannelRegistrationPayload *expectedPayload = [[UAChannelRegistrationPayload alloc] init];
    expectedPayload.language = [[NSLocale autoupdatingCurrentLocale] objectForKey:NSLocaleLanguageCode];
    expectedPayload.country = [[NSLocale autoupdatingCurrentLocale] objectForKey:NSLocaleCountryCode];
    expectedPayload.timeZone = @"cool zone";
    expectedPayload.setTags = NO;
    expectedPayload.appVersion = [UAUtils bundleShortVersionString];
    expectedPayload.SDKVersion = [UAirshipVersion get];
    expectedPayload.deviceOS = [UIDevice currentDevice].systemVersion;
    expectedPayload.deviceModel = [UAUtils deviceModelName];
    expectedPayload.carrier = [UAUtils carrierName];

    XCTestExpectation *createdPayload = [self expectationWithDescription:@"create payload"];

    [self.channel createChannelPayloadWithCompletionHandler:^(UAChannelRegistrationPayload * _Nonnull payload) {
        XCTAssertEqualObjects(payload, expectedPayload);
        [createdPayload fulfill];
    }];

    [self waitForTestExpectations];
}

/**
 * Test channel registration payload when channel tag registration is disabled.
 */
- (void)testRegistrationPayloadDataCollectionDisabled {
    self.channel.channelTagRegistrationEnabled = YES;
    self.privacyManager.enabledFeatures = UAFeaturesNone;

    self.channel.tags = @[@"cool", @"story"];
    [[[self.mockTimeZone stub] andReturn:@"cool zone"] name];

    UAChannelRegistrationPayload *expectedPayload = [[UAChannelRegistrationPayload alloc] init];
    expectedPayload.setTags = YES;
    expectedPayload.tags = @[];

    XCTestExpectation *createdPayload = [self expectationWithDescription:@"create payload"];

    [self.channel createChannelPayloadWithCompletionHandler:^(UAChannelRegistrationPayload * _Nonnull payload) {
        XCTAssertEqualObjects(payload, expectedPayload);
        [createdPayload fulfill];
    }];

    [self waitForTestExpectations];
}

/**
 * Test extending CRA payloads.
 */
- (void)testExtendingPayload {
    [self.channel addChannelExtenderBlock:^(UAChannelRegistrationPayload *payload, UAChannelRegistrationExtenderCompletionHandler completionHandler) {
        payload.pushAddress = @"WHAT!";
        completionHandler(payload);
    }];

    [self.channel addChannelExtenderBlock:^(UAChannelRegistrationPayload *payload, UAChannelRegistrationExtenderCompletionHandler completionHandler) {
        payload.pushAddress = [NSString stringWithFormat:@"%@ %@", payload.pushAddress, @"OK!"];
        completionHandler(payload);
    }];

    XCTestExpectation *createdPayload = [self expectationWithDescription:@"create payload"];
    [self.channel createChannelPayloadWithCompletionHandler:^(UAChannelRegistrationPayload * _Nonnull payload) {
        XCTAssertEqualObjects(@"WHAT! OK!", payload.pushAddress);
        [createdPayload fulfill];
    }];

    [self waitForTestExpectations];
}

/**
 * Test extending CRA payloads always calls blocks on the main queue.
 */
- (void)testExtendingPayloadBackgroundQueue {
    [self.channel addChannelExtenderBlock:^(UAChannelRegistrationPayload *payload, UAChannelRegistrationExtenderCompletionHandler completionHandler) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            payload.pushAddress = @"WHAT!";
            completionHandler(payload);
        });
    }];

    __block BOOL isMainThread;
    [self.channel addChannelExtenderBlock:^(UAChannelRegistrationPayload *payload, UAChannelRegistrationExtenderCompletionHandler completionHandler) {
        isMainThread = [NSThread currentThread].isMainThread;
        payload.pushAddress = [NSString stringWithFormat:@"%@ %@", payload.pushAddress, @"OK!"];
        completionHandler(payload);
    }];

    XCTestExpectation *createdPayload = [self expectationWithDescription:@"create payload"];
    [self.channel createChannelPayloadWithCompletionHandler:^(UAChannelRegistrationPayload * _Nonnull payload) {
        XCTAssertEqualObjects(@"WHAT! OK!", payload.pushAddress);
        [createdPayload fulfill];
    }];

    [self waitForTestExpectations];
    XCTAssertTrue(isMainThread);
}

/**
 * Test applicationDidBecomeActive, when run after app was backgrounded, does register
 */
- (void)testApplicationDidBecomeActiveAfterBackgrounding {
    // Expect UAChannel to update channel registration
    [[self.mockChannelRegistrar expect] registerForcefully:NO];

    // TEST
    [self.notificationCenter postNotificationName:UAAppStateTracker.didTransitionToForeground object:nil];

    // VERIFY
    XCTAssertNoThrow([self.mockChannelRegistrar verify], @"should update channel registration");
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

    [self.channel channelCreatedWithChannelID:@"someChannelID" existing:YES];

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

    [self.channel channelCreatedWithChannelID:@"someChannelID" existing:NO];

    [self waitForTestExpectations];
    XCTAssertEqualObjects(expectedUserInfo, notification.userInfo);
}

- (void)testCreatedIdentifierPassedToAudienceManager {
    [[self.mockAudienceManager expect] setChannelID:@"foo"];
    [self.channel channelCreatedWithChannelID:@"foo" existing:NO];
    [self.mockAudienceManager verify];
}

- (void)testInitialIdentifierPassedToAudienceManager {
    self.channelIDFromMockChannelRegistrar = @"foo";
    [[self.mockAudienceManager expect] setChannelID:@"foo"];
    self.channel = [self createChannel];
    [self.mockAudienceManager verify];
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

/**
 * Test update registration is called following the background refresh status change notification
 */
- (void)testApplicationBackgroundRefreshStatusCreatesChannel {
    // Expect UAChannel to update channel registration
    [[self.mockChannelRegistrar expect] registerForcefully:NO];

    [self.notificationCenter postNotificationName:UIApplicationBackgroundRefreshStatusDidChangeNotification object:nil];

    XCTAssertNoThrow([self.mockChannelRegistrar verify], @"Channel registration should be called");
}

/**
 * Test addTag method
 */
- (void)testAddTag {
    NSString *tag = @"test_tag";

    [self.channel addTag:tag];

    XCTAssertEqualObjects(tag, self.channel.tags[0], @"Tag should be set");
}

/**
 * Test addTags method
 */
- (void)testAddTags {
    XCTAssertEqual(self.channel.tags.count, 0);

    NSArray *tags = @[@"tag1", @"tag2"];

    [self.channel addTags:tags];

    XCTAssertEqual(self.channel.tags.count, 2, @"Tags should be set");
    XCTAssertTrue([[NSSet setWithArray:self.channel.tags] isEqualToSet:[NSSet setWithArray:tags]], @"Tags are not added correctly");
}

/**
 * Test removeTag method
 */
- (void)testAddRemoveTag {
    NSString *tag = @"tag1";

    [self.channel addTag:tag];

    XCTAssertEqual(self.channel.tags.count, 1, @"Should have added a tag");
    XCTAssertEqualObjects(self.channel.tags[0], @"tag1", @"Should have added tag 1");

    [self.channel removeTag:tag];

    XCTAssertEqual(self.channel.tags.count, 0, @"Tag should be removed");
}

/**
 * Test removeTags method
 */
- (void)testAddRemoveTags {
    NSArray *tags = @[@"tag1", @"tag2",@"tag3"];

    [self.channel addTags:tags];

    XCTAssertEqual(self.channel.tags.count, 3, @"Should have added 3 tags");
    XCTAssertTrue([[NSSet setWithArray:self.channel.tags] isEqualToSet:[NSSet setWithArray:tags]], @"Tags are not added correctly");

    NSArray *tagsToRemove = @[@"tag1", @"tag2"];

    [self.channel removeTags:tagsToRemove];

    XCTAssertEqual(self.channel.tags.count, 1, @"Tags should be removed");
    XCTAssertEqualObjects(self.channel.tags[0], @"tag3", @"The remianing tag should be tag3");
}

/**
 * Test registrationSucceded method if channelID is not set
 */
- (void)testRegistrationSucceededWithoutChannelID {
    id mockNotificationCenter = [self mockForClass:[NSNotificationCenter class]];
    self.channel.notificationCenter = mockNotificationCenter;

    [[mockNotificationCenter reject] postNotificationName:UAChannelUpdatedEvent object:OCMOCK_ANY userInfo:OCMOCK_ANY];
    [self.channel registrationSucceeded];
    [mockNotificationCenter verify];
}

/**
 * Test registrationSucceded method
 */
- (void)testRegistrationSucceededWithChannelID {
    id mockNotificationCenter = [self mockForClass:[NSNotificationCenter class]];
    self.channel.notificationCenter = mockNotificationCenter;

    self.channelIDFromMockChannelRegistrar = @"123456";
    [[mockNotificationCenter expect] postNotificationName:UAChannelUpdatedEvent object:OCMOCK_ANY userInfo:OCMOCK_ANY];
    [self.channel registrationSucceeded];
    [mockNotificationCenter verify];
}

/**
 * Test registrationFailed method
 */
- (void)testRegistrationFailed {
    id mockNotificationCenter = [self mockForClass:[NSNotificationCenter class]];
    self.channel.notificationCenter = mockNotificationCenter;
    [[mockNotificationCenter expect] postNotificationName:UAChannelRegistrationFailedEvent object:OCMOCK_ANY userInfo:OCMOCK_ANY];
    [self.channel registrationFailed];
    [mockNotificationCenter verify];
}

/**
 * Test channelCreated method
 */
- (void)testChannelCreated {
    id mockNotificationCenter = [self mockForClass:[NSNotificationCenter class]];
    self.channel.notificationCenter = mockNotificationCenter;
    [[mockNotificationCenter expect] postNotificationName:UAChannelCreatedEvent object:OCMOCK_ANY userInfo:OCMOCK_ANY];
    [self.channel channelCreatedWithChannelID:@"123456" existing:YES];
    [mockNotificationCenter verify];
}

/**
 * Test CRA is updated when data collection changes.
 */
- (void)testUpdateRegistrationOnDataCollectionChanged {
    [[self.mockChannelRegistrar expect] registerForcefully:NO];
    [self.channel onEnabledFeaturesChanged];
    [self.mockChannelRegistrar verify];
}

- (void)testConfigUpdateChannelCreationDisabled {
    self.channel.channelCreationEnabled = NO;

    [[self.mockChannelRegistrar reject] performFullRegistration];

    [self.notificationCenter postNotificationName:UARemoteConfigURLManagerConfigUpdated object:nil];

    [self.mockChannelRegistrar verify];
}

- (void)testConfigUpdateChannelCreationEnabled {
    self.channel.channelCreationEnabled = YES;
    self.channelIDFromMockChannelRegistrar = @"some-id";

    [[self.mockChannelRegistrar expect] performFullRegistration];

    [self.notificationCenter postNotificationName:UARemoteConfigURLManagerConfigUpdated object:nil];

    [self.mockChannelRegistrar verify];
}

@end

