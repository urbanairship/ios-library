/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UAChannel+Internal.h"
#import "UAChannelRegistrar+Internal.h"
#import "UAChannelRegistrationPayload+Internal.h"
#import "UATestDispatcher.h"
#import "UAUtils+Internal.h"
#import "UAUserData+Internal.h"
#import "UATestDate.h"
#import "UAAttributePendingMutations.h"
#import "UAActionResult.h"
#import "UAirship+Internal.h"
#import "UAActionRunner.h"
#import "UAAppIntegration+Internal.h"
#import "UAPush+Internal.h"
#import "UALocaleManager.h"
#import "UATaskManager.h"

@import AirshipCore;

static NSString * const UAChannelTagUpdateTaskID = @"UAChannel.tags.update";
static NSString * const UAChannelAttributeUpdateTaskID = @"UAChannel.attributes.update";

@interface UAChannel()
- (void)onEnabledFeaturesChanged;
@end

@interface UAChannelTest : UAAirshipBaseTest
@property(nonatomic, strong) id mockTagGroupsRegistrar;
@property(nonatomic, strong) id mockAttributeRegistrar;
@property(nonatomic, strong) id mockChannelRegistrar;
@property(nonatomic, strong) id mockLocaleManager;
@property(nonatomic, strong) id mockTimeZone;
@property(nonatomic, strong) NSNotificationCenter *notificationCenter;
@property(nonatomic, strong) UAChannel *channel;
@property(nonatomic, strong) UAPrivacyManager *privacyManager;
@property(nonatomic, copy) NSString *channelIDFromMockChannelRegistrar;
@property(nonatomic, copy) NSString *deviceToken;
@property(nonatomic, strong) UATestDate *testDate;
@property (nonatomic, strong) id mockedApplication;
@property (nonatomic, strong) id mockedAirship;
@property (nonatomic, strong) id mockedPush;
@property (nonatomic, strong) id mockedActionRunner;
@property (nonatomic, strong) id mockTaskManager;
@property(nonatomic, copy) void (^launchHandler)(id<UATask>);
@end

@interface UAChannel()
- (void)registrationSucceeded;
- (void)registrationFailed;
- (void)channelCreated:(NSString *)channelID
              existing:(BOOL)existing;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@end

@implementation UAChannelTest

- (void)setUp {
    [super setUp];

    self.mockedApplication = [self mockForClass:[UIApplication class]];
    [[[self.mockedApplication stub] andReturn:self.mockedApplication] sharedApplication];

    self.mockTagGroupsRegistrar = [self mockForClass:[UATagGroupsRegistrar class]];
    self.mockAttributeRegistrar = [self mockForClass:[UAAttributeRegistrar class]];
    self.notificationCenter = [[NSNotificationCenter alloc] init];

    self.mockTimeZone = [self mockForClass:[NSTimeZone class]];
    [[[self.mockTimeZone stub] andReturn:self.mockTimeZone] defaultTimeZone];

    self.mockTagGroupsRegistrar = [self mockForClass:[UATagGroupsRegistrar class]];

    self.notificationCenter = [[NSNotificationCenter alloc] init];

    // Set up a mocked device api client
    self.mockChannelRegistrar = [self mockForClass:[UAChannelRegistrar class]];

    self.mockLocaleManager = [self mockForClass:[UALocaleManager class]];
    [[[self.mockLocaleManager stub] andReturn:[NSLocale autoupdatingCurrentLocale]] currentLocale];

    self.testDate = [[UATestDate alloc] initWithAbsoluteTime:[NSDate date]];

    self.mockTaskManager = [self mockForClass:[UATaskManager class]];

    // Capture the task launcher
    [[[self.mockTaskManager stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        self.launchHandler =  (__bridge void (^)(id<UATask>))arg;
    }] registerForTaskWithIDs:@[UAChannelTagUpdateTaskID, UAChannelAttributeUpdateTaskID] dispatcher:OCMOCK_ANY launchHandler:OCMOCK_ANY];
    
    self.privacyManager = [[UAPrivacyManager alloc] initWithDataStore:self.dataStore defaultEnabledFeatures:UAFeaturesAll];
    
    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.channel = [self createChannel];

    self.mockedPush = [self mockForClass:[UAPush class]];

    self.mockedActionRunner = [self mockForClass:[UAActionRunner class]];
    
    self.mockedAirship = [self mockForClass:[UAirship class]];
    [UAirship setSharedAirship:self.mockedAirship];
    [[[self.mockedAirship stub] andReturn:@[self.channel]] components];
    [[[self.mockedAirship stub] andReturn:self.mockedPush] push];

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
                                      tagGroupsRegistrar:self.mockTagGroupsRegistrar
                                      attributeRegistrar:self.mockAttributeRegistrar
                                           localeManager:self.mockLocaleManager
                                                    date:self.testDate
                                             taskManager:self.mockTaskManager
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

- (void)testAddTagsToDeviceTagGroupWhenChannelTagRegistrationDisabled {
    // SETUP
    self.channel.channelTagRegistrationEnabled = YES;

    // EXPECTATIONS
    [[self.mockTagGroupsRegistrar reject] addTags:OCMOCK_ANY group:OCMOCK_ANY];

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
    [[self.mockTagGroupsRegistrar reject] removeTags:OCMOCK_ANY group:OCMOCK_ANY];

    // TEST
    [self.channel removeTags:@[@"tag1"] group:@"device"];

    // VERIFY
    [self.mockTagGroupsRegistrar verify];
}

- (void)testSetTagsInDeviceTagGroupWhenChannelTagRegistrationDisabled {
    // SETUP
    self.channel.channelTagRegistrationEnabled = YES;

    // EXPECTATIONS
    [[self.mockTagGroupsRegistrar reject] setTags:OCMOCK_ANY group:OCMOCK_ANY];

    // TEST
    [self.channel setTags:@[@"tag1"] group:@"device"];

    // VERIFY
    [self.mockTagGroupsRegistrar verify];
}

- (void)testSetTagsWithGroupWhenDataCollectionDisabled {
    // SETUP
    [self.privacyManager disableFeatures:UAFeaturesTagsAndAttributes];

    // EXPECTATIONS
    [[self.mockTagGroupsRegistrar reject] setTags:OCMOCK_ANY group:OCMOCK_ANY];

    // TEST
    [self.channel setTags:@[@"tag1"] group:@"group"];

    // VERIFY
    [self.mockTagGroupsRegistrar verify];
}

- (void)testAddTagsWithGroupWhenDataCollectionDisabled {
    // SETUP
    [self.privacyManager disableFeatures:UAFeaturesTagsAndAttributes];

    // EXPECTATIONS
    [[self.mockTagGroupsRegistrar reject] addTags:OCMOCK_ANY group:OCMOCK_ANY];

    // TEST
    [self.channel addTags:@[@"tag1"] group:@"group"];

    // VERIFY
    [self.mockTagGroupsRegistrar verify];
}

- (void)testRemoveTagsWithGroupWhenDataCollectionDisabled {
    // SETUP
    [self.privacyManager disableFeatures:UAFeaturesTagsAndAttributes];

    // EXPECTATIONS
    [[self.mockTagGroupsRegistrar reject] removeTags:OCMOCK_ANY group:OCMOCK_ANY];

    // TEST
    [self.channel removeTags:@[@"tag1"] group:@"group"];

    // VERIFY
    [self.mockTagGroupsRegistrar verify];
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

    [self.channel createChannelPayload:^(UAChannelRegistrationPayload * _Nonnull payload) {
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

    [self.channel createChannelPayload:^(UAChannelRegistrationPayload * _Nonnull payload) {
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

    [self.channel createChannelPayload:^(UAChannelRegistrationPayload * _Nonnull payload) {
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
    [self.channel createChannelPayload:^(UAChannelRegistrationPayload * _Nonnull payload) {
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
    [self.channel createChannelPayload:^(UAChannelRegistrationPayload * _Nonnull payload) {
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

- (void)testInitialIdentifierPassedToRegistrars {
    [[self.mockTagGroupsRegistrar expect] setIdentifier:self.channelIDFromMockChannelRegistrar clearPendingOnChange:NO];
    [[self.mockAttributeRegistrar expect] setIdentifier:self.channelIDFromMockChannelRegistrar clearPendingOnChange:NO];

    self.channel = [self createChannel];

    [self.mockTagGroupsRegistrar verify];
    [self.mockAttributeRegistrar verify];
}

- (void)testCreatedIdentifierPassedToRegistrars {
    [[self.mockTagGroupsRegistrar expect] setIdentifier:@"foo" clearPendingOnChange:NO];
    [[self.mockAttributeRegistrar expect] setIdentifier:@"foo" clearPendingOnChange:NO];

    [self.channel channelCreated:@"foo" existing:NO];

    [self.mockTagGroupsRegistrar verify];
    [self.mockAttributeRegistrar verify];
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
 * Tests adding a channel attribute enqueues an attribute update task.
 */
- (void)testAddChannelAttribute {
    [self.mockTimeZone stopMocking];

    UAAttributeMutations *addMutation = [UAAttributeMutations mutations];
    [addMutation setString:@"string" forAttribute:@"attribute"];

    UAAttributePendingMutations *expectedPendingMutations = [UAAttributePendingMutations pendingMutationsWithMutations:addMutation date:self.testDate];

    self.channelIDFromMockChannelRegistrar = @"someChannel";

    [[self.mockAttributeRegistrar expect] savePendingMutations:[OCMArg checkWithBlock:^BOOL(id obj) {
        UAAttributePendingMutations *pendingMutations = (UAAttributePendingMutations *)obj;
        return [pendingMutations.payload isEqualToDictionary:expectedPendingMutations.payload];
    }]];

    [[self.mockTaskManager expect] enqueueRequestWithID:UAChannelAttributeUpdateTaskID options:OCMOCK_ANY];

    [self.channel applyAttributeMutations:addMutation];
    [self.mockTaskManager verify];
}

/**
 * Tests adding a channel attribute results in a save but does not result in a registration call to update with mutations when no channel is present.
 */
- (void)testAddChannelAttributeNoChannel {
    [self.mockTimeZone stopMocking];

    UAAttributeMutations *addMutation = [UAAttributeMutations mutations];

    [addMutation setString:@"string" forAttribute:@"attribute"];
    self.testDate = [[UATestDate alloc] initWithAbsoluteTime:[NSDate date]];

    [UAAttributePendingMutations pendingMutationsWithMutations:addMutation
    date:self.testDate];

    [[self.mockAttributeRegistrar expect] savePendingMutations:OCMOCK_ANY];

    UATaskRequestOptions *options = [UATaskRequestOptions optionsWithConflictPolicy:UATaskConflictPolicyAppend requiresNetwork:YES extras:nil];
    id mockTask = [self mockForProtocol:@protocol(UATask)];

    [[[mockTask stub] andReturn:UAChannelAttributeUpdateTaskID] taskID];
    [[[mockTask stub] andReturn:options] requestOptions];

    [[self.mockAttributeRegistrar reject] updateAttributesWithCompletionHandler:OCMOCK_ANY];

    [self.channel applyAttributeMutations:addMutation];

    [self.mockAttributeRegistrar verify];
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
 * Test removeTags:group: method
 */
- (void)testRemoveTagsFromGroup {
    NSArray *tags = @[@"tag1", @"tag2",@"tag3"];
    NSString *tagGroup = @"test_group";

    self.channel.channelTagRegistrationEnabled = NO;
    [[self.mockTagGroupsRegistrar expect] removeTags:tags group:tagGroup];
    [self.channel removeTags:tags group:tagGroup];
    [self.mockTagGroupsRegistrar verify];

    self.channel.channelTagRegistrationEnabled = YES;
    [[self.mockTagGroupsRegistrar reject] removeTags:tags group:tagGroup];
    [self.channel removeTags:tags group:@"device"];
    [self.mockTagGroupsRegistrar verify];
}

/**
 * Test setTags:group: method
 */
- (void)testSetTagsForGroup {
    NSArray *tags = @[@"tag1", @"tag2",@"tag3"];
    NSString *tagGroup = @"test_group";

    self.channel.channelTagRegistrationEnabled = NO;
    [[self.mockTagGroupsRegistrar expect] setTags:tags group:tagGroup];
    [self.channel setTags:tags group:tagGroup];
    [self.mockTagGroupsRegistrar verify];

    self.channel.channelTagRegistrationEnabled = YES;
    [[self.mockTagGroupsRegistrar reject] setTags:tags group:tagGroup];
    [self.channel setTags:tags group:@"device"];
    [self.mockTagGroupsRegistrar verify];
}

- (void)testUpdateTagGroups {
    [self.privacyManager enableFeatures:UAFeaturesTagsAndAttributes];
    self.channelIDFromMockChannelRegistrar = @"123456";
    self.channel.componentEnabled = YES;

    id mockTask = [self mockForProtocol:@protocol(UATask)];
    [[[mockTask stub] andReturn:UAChannelTagUpdateTaskID] taskID];
    [[mockTask expect] taskCompleted];

    [[[self.mockTagGroupsRegistrar expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        void (^completionHandler)(UATagGroupsUploadResult) = (__bridge void (^)(UATagGroupsUploadResult))arg;
        completionHandler(UATagGroupsUploadResultFinished);
    }] updateTagGroupsWithCompletionHandler:OCMOCK_ANY];

    [[self.mockTaskManager expect] enqueueRequestWithID:UAChannelTagUpdateTaskID options:OCMOCK_ANY];

    self.launchHandler(mockTask);

    [self.mockTagGroupsRegistrar verify];
    [self.mockTaskManager verify];
    [mockTask verify];
}

- (void)testUpdateTagsFailed {
    [self.privacyManager enableFeatures:UAFeaturesTagsAndAttributes];
    self.channelIDFromMockChannelRegistrar = @"123456";
    self.channel.componentEnabled = YES;

    id mockTask = [self mockForProtocol:@protocol(UATask)];
    [[[mockTask stub] andReturn:UAChannelTagUpdateTaskID] taskID];
    [mockTask taskFailed];

    [[[self.mockTagGroupsRegistrar expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        void (^completionHandler)(UATagGroupsUploadResult) = (__bridge void (^)(UATagGroupsUploadResult))arg;
        completionHandler(UATagGroupsUploadResultFailed);
    }] updateTagGroupsWithCompletionHandler:OCMOCK_ANY];

    [[self.mockTaskManager reject] enqueueRequestWithID:UAChannelTagUpdateTaskID options:OCMOCK_ANY];

    self.launchHandler(mockTask);

    [self.mockTagGroupsRegistrar verify];
    [self.mockTaskManager verify];
    [mockTask verify];
}

- (void)testUpdateTagsUpToDate {
    [self.privacyManager enableFeatures:UAFeaturesTagsAndAttributes];
    self.channelIDFromMockChannelRegistrar = @"123456";
    self.channel.componentEnabled = YES;

    id mockTask = [self mockForProtocol:@protocol(UATask)];
    [[[mockTask stub] andReturn:UAChannelTagUpdateTaskID] taskID];
    [mockTask taskFailed];

    [[[self.mockTagGroupsRegistrar expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        void (^completionHandler)(UATagGroupsUploadResult) = (__bridge void (^)(UATagGroupsUploadResult))arg;
        completionHandler(UATagGroupsUploadResultUpToDate);
    }] updateTagGroupsWithCompletionHandler:OCMOCK_ANY];

    [[self.mockTaskManager reject] enqueueRequestWithID:UAChannelTagUpdateTaskID options:OCMOCK_ANY];

    self.launchHandler(mockTask);

    [self.mockTagGroupsRegistrar verify];
    [self.mockTaskManager verify];
    [mockTask verify];
}

- (void)testUpdateAttributes {
    self.channelIDFromMockChannelRegistrar = @"123456";
    self.channel.componentEnabled = YES;

    id mockTask = [self mockForProtocol:@protocol(UATask)];
    [[[mockTask stub] andReturn:UAChannelAttributeUpdateTaskID] taskID];
    [[mockTask expect] taskCompleted];

    [[[self.mockAttributeRegistrar expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        void (^completionHandler)(UAAttributeUploadResult) = (__bridge void (^)(UAAttributeUploadResult))arg;
        completionHandler(UAAttributeUploadResultFinished);
    }] updateAttributesWithCompletionHandler:OCMOCK_ANY];

    [[self.mockTaskManager expect] enqueueRequestWithID:UAChannelAttributeUpdateTaskID options:OCMOCK_ANY];

    self.launchHandler(mockTask);

    [self.mockAttributeRegistrar verify];
    [self.mockTaskManager verify];
    [mockTask verify];
}

- (void)testUpdateAttributesFailed {
    self.channelIDFromMockChannelRegistrar = @"123456";
    self.channel.componentEnabled = YES;

    id mockTask = [self mockForProtocol:@protocol(UATask)];
    [[[mockTask stub] andReturn:UAChannelAttributeUpdateTaskID] taskID];
    [[mockTask expect] taskFailed];

    [[[self.mockAttributeRegistrar expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        void (^completionHandler)(UAAttributeUploadResult) = (__bridge void (^)(UAAttributeUploadResult))arg;
        completionHandler(UAAttributeUploadResultFailed);
    }] updateAttributesWithCompletionHandler:OCMOCK_ANY];

    [[self.mockTaskManager reject] enqueueRequestWithID:UAChannelAttributeUpdateTaskID options:OCMOCK_ANY];

    self.launchHandler(mockTask);

    [self.mockAttributeRegistrar verify];
    [self.mockTaskManager verify];
    [mockTask verify];
}

- (void)testUpdateAttributesUpToDate {
    self.channelIDFromMockChannelRegistrar = @"123456";
    self.channel.componentEnabled = YES;

    id mockTask = [self mockForProtocol:@protocol(UATask)];
    [[[mockTask stub] andReturn:UAChannelAttributeUpdateTaskID] taskID];
    [[mockTask expect] taskCompleted];

    [[[self.mockAttributeRegistrar expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        void (^completionHandler)(UAAttributeUploadResult) = (__bridge void (^)(UAAttributeUploadResult))arg;
        completionHandler(UAAttributeUploadResultUpToDate);
    }] updateAttributesWithCompletionHandler:OCMOCK_ANY];

    [[self.mockTaskManager reject] enqueueRequestWithID:UAChannelAttributeUpdateTaskID options:OCMOCK_ANY];

    self.launchHandler(mockTask);

    [self.mockAttributeRegistrar verify];
    [self.mockTaskManager verify];
    [mockTask verify];
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
    [self.channel channelCreated:@"123456" existing:YES];
    [mockNotificationCenter verify];
}

/**
 * Test channelCreated method if channelID is not set
 */
- (void)testChannelCreatedWithoutChannelID {
    id mockNotificationCenter = [self mockForClass:[NSNotificationCenter class]];
    self.channel.notificationCenter = mockNotificationCenter;
    [[mockNotificationCenter reject] postNotificationName:UAChannelCreatedEvent object:OCMOCK_ANY userInfo:OCMOCK_ANY];
    [self.channel channelCreated:nil existing:YES];
    [mockNotificationCenter verify];
}

/**
 * Test application:didReceiveRemoteNotification:fetchCompletionHandler in the
 * background
 */
- (void)testReceivedRemoteNotificationBackgroundWithSilentNotification {

    // Notification
    NSDictionary *notification = @{
        @"aps": @{
                @"content-available": @1,
        }
    };

    XCTAssertNil(self.channel.identifier, @"Channel identifier should be null");

    XCTestExpectation *handlerExpectation = [self expectationWithDescription:@"Completion handler called"];

    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateBackground)] applicationState];

    __block BOOL completionHandlerCalled = NO;
    BOOL (^handlerCheck)(id obj) = ^(id obj) {
        void (^handler)(UAActionResult *) = obj;
        if (handler) {
            UAActionResult *testResult = [UAActionResult resultWithValue:@"test" withFetchResult:UAActionFetchResultNewData];
            handler(testResult);
        }
        return YES;
    };

    NSDictionary *expectedMetadata = @{ UAActionMetadataForegroundPresentationKey: @(NO),
                                        UAActionMetadataPushPayloadKey:notification};

    NSDictionary *actionsPayload = [UAAppIntegration actionsPayloadForNotificationContent:
                                    [UANotificationContent notificationWithNotificationInfo:notification] actionIdentifier:nil];

    // Expect actions to be run for the action identifier
    [[self.mockedActionRunner expect] runActionsWithActionValues:actionsPayload
                                                       situation:UASituationBackgroundPush
                                                        metadata:expectedMetadata
                                               completionHandler:[OCMArg checkWithBlock:handlerCheck]];

    // Expect the UAPush to be called
    [[self.mockedPush expect] handleRemoteNotification:[OCMArg checkWithBlock:^BOOL(id obj) {
        UANotificationContent *content = obj;
        return [content.notificationInfo isEqualToDictionary:notification];
    }] foreground:NO completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^handler)(UIBackgroundFetchResult) = obj;
        handler(UIBackgroundFetchResultNewData);
        return YES;
    }]];

    [[self.mockChannelRegistrar expect] registerForcefully:NO];

    // Call the integration
    [UAAppIntegration application:self.mockedApplication
     didReceiveRemoteNotification:notification
           fetchCompletionHandler:^(UIBackgroundFetchResult result) {
        completionHandlerCalled = YES;
        XCTAssertEqual(result, UIBackgroundFetchResultNewData);
        [handlerExpectation fulfill];
    }];

    // Verify everything
    [self waitForTestExpectations];
    [self.mockedActionRunner verify];
    [self.mockedPush verify];
    [self.mockChannelRegistrar verify];

    XCTAssertTrue(completionHandlerCalled, @"Completion handler should be called.");
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
