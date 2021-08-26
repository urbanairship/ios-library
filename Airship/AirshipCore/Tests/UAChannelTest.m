/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UAUserData+Internal.h"
#import "UAActionResult.h"
#import "UAirship+Internal.h"
#import "UAAppIntegration+Internal.h"
#import "AirshipTests-Swift.h"

@import AirshipCore;

@interface UAChannelTest : UABaseTest
@property(nonatomic, strong) UATestChannelRegistrar *testRegistrar;
@property(nonatomic, strong) UATestLocaleManager *testLocaleManager;
@property(nonatomic, strong) NSNotificationCenter *notificationCenter;
@property(nonatomic, strong) UAChannel *channel;
@property(nonatomic, strong) UAPrivacyManager *privacyManager;
@property(nonatomic, strong) UATestChannelAudienceManager *testAudienceManager;
@property (nonatomic, strong) UAConfig *config;
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@end

@implementation UAChannelTest

- (void)setUp {
    [super setUp];
    self.config = [[UAConfig alloc] init];
    self.dataStore = [[UAPreferenceDataStore alloc] initWithKeyPrefix:NSUUID.UUID.UUIDString];

    self.notificationCenter = [[NSNotificationCenter alloc] init];
    self.testAudienceManager = [[UATestChannelAudienceManager alloc] init];

    self.notificationCenter = [[NSNotificationCenter alloc] init];
    self.testRegistrar = [[UATestChannelRegistrar alloc] init];
    self.testLocaleManager = [[UATestLocaleManager alloc] init];

    self.privacyManager = [[UAPrivacyManager alloc] initWithDataStore:self.dataStore
                                               defaultEnabledFeatures:UAFeaturesAll
                                                   notificationCenter:self.notificationCenter];

    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.channel = [self createChannel];
}

- (UAChannel *) createChannel {
    UARuntimeConfig *config = [[UARuntimeConfig alloc] initWithConfig:self.config dataStore:self.dataStore];
    return [[UAChannel alloc] initWithDataStore:self.dataStore
                                         config:config
                                 privacyManager:self.privacyManager
                                  localeManager:self.testLocaleManager
                                audienceManager:self.testAudienceManager
                               channelRegistrar:self.testRegistrar
                             notificationCenter:self.notificationCenter];
}

- (void)testTags {
    NSArray *tags = @[@"tag-one", @"tag-two"];
    self.channel.tags = tags;

    XCTAssertEqual((NSUInteger)2, self.channel.tags.count, @"should have added 2 tags");
    XCTAssertEqualObjects(tags, self.channel.tags, @"tags are not stored correctly");

    self.channel.tags = @[];
    XCTAssertEqual((NSUInteger)0, self.channel.tags.count, @"tags should return an empty array even when set to nil");
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

- (void)testDataCollectionDisabledClearsTags {
    self.channel.tags = @[@"cool", @"rad"];

    [self.privacyManager disableFeatures:UAFeaturesTagsAndAttributes];

    XCTAssertEqualObjects(self.channel.tags, @[]);
}

/**
 * Tests update registration when channel creation flag is disabled.
 */
- (void)testChannelCreationFlagDisabled {
    // Test when channel creation is disabled
    self.testRegistrar.registerCalled = NO;
    self.config.isChannelCreationDelayEnabled = YES;
    self.channel = [self createChannel];
    [self.channel updateRegistration];

    XCTAssertFalse(self.testRegistrar.registerCalled);
}

/**
 * Tests update registration when channel creation flag is enabled.
 */
- (void)testChannelCreationFlagEnabled {
    // Test when channel creation is enabled
    self.testRegistrar.registerCalled = NO;
    self.config.isChannelCreationDelayEnabled = YES;
    self.channel = [self createChannel];

    [self.channel enableChannelCreation];
    [self.channel updateRegistration];

    XCTAssertTrue(self.testRegistrar.registerCalled);
}

/**
 * Tests that registration updates when channel creation flag is enabled.
 */
- (void)testEnableChannelCreation {
    // Test when channel creation starts disabled
    self.testRegistrar.registerCalled = NO;
    self.config.isChannelCreationDelayEnabled = YES;
    self.channel = [self createChannel];

    // TEST
    [self.channel enableChannelCreation];

    // VERIFY
    XCTAssertTrue(self.testRegistrar.registerCalled);
}

/**
 * Tests enabling channel delay after channel ID has been registered.
 */
- (void)testEnableChannelDelayWithChannelID {
    // Set channelCreationDelayEnabled to NO
    self.config.isChannelCreationDelayEnabled = NO;

    // Init channel
    self.channel = [self createChannel];

    // Ensure channel creation enabled is YES
    XCTAssertTrue(self.channel.isChannelCreationEnabled);

    // Set channelCreationDelayEnabled to YES
    self.config.isChannelCreationDelayEnabled = YES;

    // Init channel
    self.channel = [self createChannel];

    // Ensure channel creation enabled is NO
    XCTAssertFalse(self.channel.isChannelCreationEnabled);

    // Have the channel registrar return a mocked identifier for channel init
    self.testRegistrar.channelID = @"someChannelID";

    self.channel = [self createChannel];

    // Ensure channel creation enabled is YES
    XCTAssertTrue(self.channel.isChannelCreationEnabled);
}

/**
 * Test channel registration payload.
 */
- (void)testRegistrationPayload {
    self.channel.isChannelTagRegistrationEnabled = YES;
    [self.privacyManager enableFeatures:UAFeaturesTagsAndAttributes];

    self.channel.tags = @[@"cool", @"story"];

    UAChannelRegistrationPayload *expectedPayload = [[UAChannelRegistrationPayload alloc] init];
    expectedPayload.channel.language = [[NSLocale autoupdatingCurrentLocale] objectForKey:NSLocaleLanguageCode];
    expectedPayload.channel.country = [[NSLocale autoupdatingCurrentLocale] objectForKey:NSLocaleCountryCode];
    expectedPayload.channel.timeZone = [NSTimeZone defaultTimeZone].name;
    expectedPayload.channel.tags = @[@"cool", @"story"];
    expectedPayload.channel.setTags = YES;
    expectedPayload.channel.appVersion = [UAUtils bundleShortVersionString];
    expectedPayload.channel.sdkVersion = [UAirshipVersion get];
    expectedPayload.channel.deviceOS = [UIDevice currentDevice].systemVersion;
    expectedPayload.channel.deviceModel = [UAUtils deviceModelName];
    expectedPayload.channel.carrier = [UAUtils carrierName];

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
    self.channel = [self createChannel];

    [self.privacyManager enableFeatures:UAFeaturesTagsAndAttributes];
    self.channel.isChannelTagRegistrationEnabled = NO;
    self.channel.tags = @[@"cool", @"story"];

    UAChannelRegistrationPayload *expectedPayload = [[UAChannelRegistrationPayload alloc] init];
    expectedPayload.channel.language = [[NSLocale autoupdatingCurrentLocale] objectForKey:NSLocaleLanguageCode];
    expectedPayload.channel.country = [[NSLocale autoupdatingCurrentLocale] objectForKey:NSLocaleCountryCode];
    expectedPayload.channel.timeZone = [NSTimeZone defaultTimeZone].name;
    expectedPayload.channel.setTags = NO;
    expectedPayload.channel.appVersion = [UAUtils bundleShortVersionString];
    expectedPayload.channel.sdkVersion = [UAirshipVersion get];
    expectedPayload.channel.deviceOS = [UIDevice currentDevice].systemVersion;
    expectedPayload.channel.deviceModel = [UAUtils deviceModelName];
    expectedPayload.channel.carrier = [UAUtils carrierName];

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
    self.privacyManager.enabledFeatures = UAFeaturesNone;

    self.channel.tags = @[@"cool", @"story"];

    UAChannelRegistrationPayload *expectedPayload = [[UAChannelRegistrationPayload alloc] init];
    expectedPayload.channel.setTags = YES;
    expectedPayload.channel.tags = @[];

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
    [self.channel addRegistrationExtender:^(UAChannelRegistrationPayload *payload, void (^ completionHandler)(UAChannelRegistrationPayload *)) {
        payload.channel.pushAddress = @"WHAT!";
        completionHandler(payload);
    }];

    [self.channel addRegistrationExtender:^(UAChannelRegistrationPayload *payload, void (^ completionHandler)(UAChannelRegistrationPayload *)) {
        payload.channel.pushAddress = [NSString stringWithFormat:@"%@ %@", payload.channel.pushAddress, @"OK!"];
        completionHandler(payload);
    }];

    XCTestExpectation *createdPayload = [self expectationWithDescription:@"create payload"];
    [self.channel createChannelPayloadWithCompletionHandler:^(UAChannelRegistrationPayload *payload) {
        XCTAssertEqualObjects(@"WHAT! OK!", payload.channel.pushAddress);
        [createdPayload fulfill];
    }];

    [self waitForTestExpectations];
}

/**
 * Test extending CRA payloads always calls blocks on the main queue.
 */
- (void)testExtendingPayloadBackgroundQueue {
    [self.channel addRegistrationExtender:^(UAChannelRegistrationPayload *payload, void (^ completionHandler)(UAChannelRegistrationPayload *)) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            payload.channel.pushAddress = @"WHAT!";
            completionHandler(payload);
        });
    }];

    __block BOOL isMainThread;
    [self.channel addRegistrationExtender:^(UAChannelRegistrationPayload *payload, void (^ completionHandler)(UAChannelRegistrationPayload *)) {
        isMainThread = [NSThread currentThread].isMainThread;
        payload.channel.pushAddress = [NSString stringWithFormat:@"%@ %@", payload.channel.pushAddress, @"OK!"];
        completionHandler(payload);
    }];

    XCTestExpectation *createdPayload = [self expectationWithDescription:@"create payload"];
    [self.channel createChannelPayloadWithCompletionHandler:^(UAChannelRegistrationPayload * _Nonnull payload) {
        XCTAssertEqualObjects(@"WHAT! OK!", payload.channel.pushAddress);
        [createdPayload fulfill];
    }];

    [self waitForTestExpectations];
    XCTAssertTrue(isMainThread);
}

/**
 * Test applicationDidBecomeActive, when run after app was backgrounded, does register
 */
- (void)testApplicationDidBecomeActiveAfterBackgrounding {
    // TEST
    [self.notificationCenter postNotificationName:UAAppStateTracker.didTransitionToForeground object:nil];

    // VERIFY
    XCTAssertTrue(self.testRegistrar.registerCalled);
}

/**
 * Test existing channel created posts an NSNotification
 */
- (void)testExistingChannelCreatedNSNotification {
    id expectedUserInfo = @{ UAChannel.channelExistingKey: @(YES),
                             UAChannel.channelIdentifierKey: @"someChannelID" };

    __block NSNotification *notification;

    XCTestExpectation *notificationFired = [self expectationWithDescription:@"Notification event fired"];
    [self.notificationCenter addObserverForName:UAChannel.channelCreatedEvent object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        notification = note;
        [notificationFired fulfill];
    }];

    [self.channel channelCreatedWithChannelID:@"someChannelID" existing:YES];

    [self waitForTestExpectations];
    XCTAssertEqualObjects(expectedUserInfo, notification.userInfo);
}

/**
 * Test new channel created posts an NSNotification of type UAChannel.channelCreatedEvent
 */
- (void)testNewChannelCreatedNSNotification {
    id expectedUserInfo = @{ UAChannel.channelExistingKey: @(NO),
                             UAChannel.channelIdentifierKey:@"someChannelID" };

    __block NSNotification *notification;

    XCTestExpectation *notificationFired = [self expectationWithDescription:@"Notification event fired"];
    [self.notificationCenter addObserverForName:UAChannel.channelCreatedEvent object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        notification = note;
        [notificationFired fulfill];
    }];

    [self.channel channelCreatedWithChannelID:@"someChannelID" existing:NO];

    [self waitForTestExpectations];
    XCTAssertEqualObjects(expectedUserInfo, notification.userInfo);
}

- (void)testCreatedIdentifierPassedToAudienceManager {
    [self.channel channelCreatedWithChannelID:@"foo" existing:NO];
    XCTAssertEqualObjects(@"foo", self.testAudienceManager.channelID);
}

- (void)testInitialIdentifierPassedToAudienceManager {
    self.testRegistrar.channelID = @"foo";
    self.channel = [self createChannel];
    XCTAssertEqualObjects(@"foo", self.testAudienceManager.channelID);
}

/**
 * Test channel updated posts an NSNotification of type UAChannelUpdatedEvent
 */
- (void)testChannelUpdatedNSNotification {
    self.testRegistrar.channelID = @"someChannelID";

    XCTestExpectation *notificationFired = [self expectationWithDescription:@"Notification event fired"];
    [self.notificationCenter addObserverForName:UAChannel.channelUpdatedEvent object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        [notificationFired fulfill];
    }];

    [self.channel registrationSucceeded];

    [self waitForTestExpectations];
}

/**
 * Test update registration is called following the background refresh status change notification
 */
- (void)testApplicationBackgroundRefreshStatusCreatesChannel {
    [self.notificationCenter postNotificationName:UIApplicationBackgroundRefreshStatusDidChangeNotification object:nil];

    XCTAssertTrue(self.testRegistrar.registerCalled);
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
    XCTestExpectation *notificationReceived = [self expectationWithDescription:@"Received"];
    [self.notificationCenter addObserverForName:UAChannel.channelUpdatedEvent
                                         object:nil
                                          queue:nil
                                     usingBlock:^(NSNotification * _Nonnull notification) {
        [notificationReceived fulfill];
    }];
    [self.channel registrationSucceeded];
    [self waitForTestExpectations];
}

/**
 * Test registrationSucceded method
 */
- (void)testRegistrationSucceededWithChannelID {
    XCTestExpectation *notificationReceived = [self expectationWithDescription:@"Received"];
    [self.notificationCenter addObserverForName:UAChannel.channelUpdatedEvent
                                         object:nil
                                          queue:nil
                                     usingBlock:^(NSNotification * _Nonnull notification) {
        [notificationReceived fulfill];
    }];
    self.testRegistrar.channelID = @"123456";
    [self.channel registrationSucceeded];
    [self waitForTestExpectations];
}

/**
 * Test registrationFailed method
 */
- (void)testRegistrationFailed {
    XCTestExpectation *notificationReceived = [self expectationWithDescription:@"Received"];
    [self.notificationCenter addObserverForName:UAChannel.channelRegistrationFailedEvent
                                         object:nil
                                          queue:nil
                                     usingBlock:^(NSNotification * _Nonnull notification) {
        [notificationReceived fulfill];
    }];
    [self.channel registrationFailed];
    [self waitForTestExpectations];
}

/**
 * Test channelCreated method
 */
- (void)testChannelCreated {
    XCTestExpectation *notificationReceived = [self expectationWithDescription:@"Received"];
    [self.notificationCenter addObserverForName:UAChannel.channelCreatedEvent
                                         object:nil
                                          queue:nil
                                     usingBlock:^(NSNotification * _Nonnull notification) {
        [notificationReceived fulfill];
    }];
    [self.channel channelCreatedWithChannelID:@"123456" existing:YES];
    [self waitForTestExpectations];
}

/**
 * Test CRA is updated when data collection changes.
 */
- (void)testUpdateRegistrationOnDataCollectionChanged {
    self.privacyManager.enabledFeatures = UAFeaturesNone;
    XCTAssertTrue(self.testRegistrar.registerCalled);
}

- (void)testConfigUpdateChannelCreationDisabled {
    self.config.isChannelCreationDelayEnabled = YES;
    self.channel = [self createChannel];

    [self.notificationCenter postNotificationName:UARuntimeConfig.configUpdatedEvent object:nil];

    XCTAssertFalse(self.testRegistrar.fullRegistrationCalled);
}

- (void)testConfigUpdateChannelCreationEnabled {
    self.testRegistrar.channelID = @"some-id";

    [self.notificationCenter postNotificationName:UARuntimeConfig.configUpdatedEvent object:nil];

    XCTAssertTrue(self.testRegistrar.fullRegistrationCalled);
}

@end

