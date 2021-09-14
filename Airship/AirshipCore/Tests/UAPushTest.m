
/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UAEvent.h"
#import "AirshipTests-Swift.h"

@import AirshipCore;

@protocol UAPushTestAnalyticsProtocol <UAAnalyticsProtocol>
@end

@interface UAPushTest : UABaseTest
@property (nonatomic, strong) id mockApplication;
@property (nonatomic, strong) UATestChannel *testChannel;
@property (nonatomic, strong) UATestAppStateTracker *testAppStateTracker;
@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) id mockPushDelegate;
@property (nonatomic, strong) id mockRegistrationDelegate;
@property (nonatomic, strong) id mockUAUtils;
@property (nonatomic, strong) id mockDefaultNotificationCategories;
@property (nonatomic, strong) id mockUNNotification;
@property (nonatomic, strong) id mockPushRegistration;
@property (nonatomic, strong) NSMutableDictionary *mockUserInfo;
@property (nonatomic, strong) id mockAnalytics;

@property (nonatomic, strong) UAPush *push;
@property (nonatomic, strong) UAPrivacyManager *privacyManager;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@property (nonatomic, copy) NSDictionary *notification;
@property (nonatomic, copy) NSData *validAPNSDeviceToken;
@property (nonatomic, assign) UAAuthorizationStatus authorizationStatus;
@property (nonatomic, assign) UAAuthorizedNotificationSettings authorizedNotificationSettings;
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> * _Nullable (^analyticHeadersBlock)(void);
@property (nonatomic, strong) UAConfig *config;
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;

@end

@implementation UAPushTest

NSString *validDeviceToken = @"0123456789abcdef0123456789abcdef";

- (void)setUp {
    [super setUp];

    self.config = [[UAConfig alloc] init];
    self.dataStore = [[UAPreferenceDataStore alloc] initWithKeyPrefix:NSUUID.UUID.UUIDString];

    self.validAPNSDeviceToken = [self dataFromHexString:validDeviceToken];
    assert([self.validAPNSDeviceToken length] <= 32);

    self.authorizationStatus = UAAuthorizationStatusAuthorized;
    self.authorizedNotificationSettings = UAAuthorizedNotificationSettingsNone;

    self.mockPushRegistration = [self mockForClass:[UAAPNSRegistration class]];
    typedef void (^GetAuthorizedSettingsCompletionBlock)(UAAuthorizedNotificationSettings, UAAuthorizationStatus);
    [[[self.mockPushRegistration stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        GetAuthorizedSettingsCompletionBlock completionHandler = (__bridge GetAuthorizedSettingsCompletionBlock)arg;
        completionHandler(self.authorizedNotificationSettings, self.authorizationStatus);
    }] getAuthorizedSettingsWithCompletionHandler:OCMOCK_ANY];

    self.notificationCenter = [[NSNotificationCenter alloc] init];

    self.notification = @{
        @"aps": @{
                @"alert": @"sample alert!",
                @"badge": @2,
                @"sound": @"cat",
                @"category": @"notificationCategory"
        },
        @"com.urbanairship.interactive_actions": @{
                @"backgroundIdentifier": @{
                        @"backgroundAction": @"backgroundActionValue"
                },
                @"foregroundIdentifier": @{
                        @"foregroundAction": @"foregroundActionValue",
                        @"otherForegroundAction": @"otherForegroundActionValue"

                },
        },
        @"someActionKey": @"someActionValue",
    };

    // Mock the nested apple types with unavailable init methods
    self.mockUNNotification = [self mockForClass:[UNNotification class]];

    //Mock the notification request
    id mockUNNotificationRequest = [self mockForClass:[UNNotificationRequest class]];
    [[[self.mockUNNotification stub] andReturn:mockUNNotificationRequest] request];

    //Mock the notification content
    id mockUNNotificationContent = [self mockForClass:[UNNotificationContent class]];
    [[[mockUNNotificationRequest stub] andReturn:mockUNNotificationContent] content];

    //Mock the notification userInfo
    self.mockUserInfo = [NSMutableDictionary dictionary];

    [[[mockUNNotificationContent stub] andReturn:self.mockUserInfo] userInfo];

    // Set up a mocked application
    self.mockApplication = [self mockForClass:[UIApplication class]];
    self.mockPushDelegate = [self mockForProtocol:@protocol(UAPushNotificationDelegate)];
    self.mockRegistrationDelegate = [self mockForProtocol:@protocol(UARegistrationDelegate)];

    self.mockDefaultNotificationCategories = [self mockForClass:[UANotificationCategories class]];

    self.testChannel = [[UATestChannel alloc] init];
    self.mockAnalytics = [self mockForProtocol:@protocol(UAPushTestAnalyticsProtocol)];

    // Capture the analytics header extender
    [[[self.mockAnalytics stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        self.analyticHeadersBlock =  (__bridge NSDictionary<NSString *, NSString *> * _Nullable (^)(void))arg;
    }] addAnalyticsHeadersBlock:OCMOCK_ANY];

    self.testAppStateTracker = [[UATestAppStateTracker alloc] init];
    self.testAppStateTracker.currentState = UAApplicationStateActive;

    self.privacyManager = [[UAPrivacyManager alloc] initWithDataStore:self.dataStore defaultEnabledFeatures:UAFeaturesAll];
    
    [self createPush];
}

- (void)tearDown {
    self.push.pushNotificationDelegate = nil;
    self.push.registrationDelegate = nil;
    self.push = nil;

    [self.mockUNNotification stopMocking];
    [super tearDown];
}

- (void)createPush {
    UARuntimeConfig *runtimeConfig = [[UARuntimeConfig alloc] initWithConfig:self.config
                                                                   dataStore:self.dataStore];
    self.push = [[UAPush alloc] initWithConfig:runtimeConfig
                                     dataStore:self.dataStore
                                       channel:self.testChannel
                                     analytics:self.mockAnalytics
                               appStateTracker:self.testAppStateTracker
                            notificationCenter:self.notificationCenter
                              pushRegistration:self.mockPushRegistration
                                   application:self.mockApplication
                                    dispatcher:[[UATestDispatcher alloc] init]
                                privacyManager:self.privacyManager];

    self.push.registrationDelegate = self.mockRegistrationDelegate;
    self.push.pushNotificationDelegate = self.mockPushDelegate;
}

- (NSData *)dataFromTokenString:(NSString *)string {
    string = [string stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSMutableData *out = [[NSMutableData alloc] init];

    unsigned char whole_byte;
    char byte_chars[3] = {'\0','\0','\0'};

    for (int i=0; i < [string length]/2; i++) {
        byte_chars[0] = [string characterAtIndex:i*2];
        byte_chars[1] = [string characterAtIndex:i*2+1];
        whole_byte = strtol(byte_chars, NULL, 16);
        [out appendBytes:&whole_byte length:1];
    }
    
    return out;
}

- (void)setDeviceToken:(NSData *)data {
    [LegacyPushTestUtils setDeviceTokenWithPush:self.push token:data];
}

/**
 * Test enabling userPushNotificationsEnabled saves its settings
 * to NSUserDefaults and updates apns registration.
 */
- (void)testUserPushNotificationsEnabled {
    // SETUP
    self.push.userPushNotificationsEnabled = NO;

    // EXPECTATIONS
    UANotificationOptions expectedOptions = UANotificationOptionAlert | UANotificationOptionBadge | UANotificationOptionSound;
    [self expectUpdatePushRegistrationWithOptions:expectedOptions categories:self.push.combinedCategories];

    // TEST
    self.push.userPushNotificationsEnabled = YES;

    // VERIFY
    XCTAssertTrue(self.push.userPushNotificationsEnabled,
                  @"userPushNotificationsEnabled should be enabled when set to YES");

    XCTAssertNoThrow([self.mockPushRegistration verify], @"[UAAPNSRegistration updateRegistrationWithOptions:categories:completionHandler:] should be called");
}

- (void)testUserPushNotificationsEnabledWhenAppIsHandlingAuthorization {
    // SETUP
    self.config.requestAuthorizationToUseNotifications = NO;
    [self createPush];

    self.push.userPushNotificationsEnabled = NO;

    // EXPECTATIONS
    [self rejectUpdatePushRegistrationWithOptions];

    // TEST
    self.push.userPushNotificationsEnabled = YES;

    // VERIFY
    XCTAssertTrue(self.push.userPushNotificationsEnabled,
                  @"userPushNotificationsEnabled should be enabled when set to YES");

    XCTAssertNoThrow([self.mockPushRegistration verify], @"[UAAPNSRegistration updateRegistrationWithOptions:categories:completionHandler:] should not be called");
}

/**
 * Test disabling userPushNotificationsEnabled saves its settings
 * to NSUserDefaults and updates push registration.
 */
- (void)testUserPushNotificationsDisabled {
    // SETUP
    self.push.userPushNotificationsEnabled = YES;
    [self setDeviceToken:self.validAPNSDeviceToken];

    // Make sure we have previously registered types
    self.authorizedNotificationSettings = UAAuthorizedNotificationSettingsBadge;

    // Make sure push is set to YES
    XCTAssertTrue(self.push.userPushNotificationsEnabled,
                  @"userPushNotificationsEnabled should default to YES");

    [self expectUpdatePushRegistrationWithOptions:UANotificationOptionNone categories:nil];

    // TEST
    self.push.userPushNotificationsEnabled = NO;

    // VERIFY
    XCTAssertFalse(self.push.userPushNotificationsEnabled,
                   @"userPushNotificationsEnabled should be disabled when set to NO");
    XCTAssertNoThrow([self.mockPushRegistration verify], @"[UAAPNSRegistration updateRegistrationWithOptions:categories:completionHandler:] should be called");
}

- (void)testUserPushNotificationsDisabledWhenAppIsHandlingAuthorization {
    // SETUP
    self.config.requestAuthorizationToUseNotifications = NO;
    [self createPush];

    self.push.userPushNotificationsEnabled = YES;
    [self setDeviceToken:self.validAPNSDeviceToken];

    // Make sure we have previously registered types
    self.authorizedNotificationSettings = UAAuthorizedNotificationSettingsBadge;

    // Make sure push is set to YES
    XCTAssertTrue(self.push.userPushNotificationsEnabled,
                  @"userPushNotificationsEnabled should default to YES");

    [self rejectUpdatePushRegistrationWithOptions];

    // TEST
    self.push.userPushNotificationsEnabled = NO;

    // VERIFY
    XCTAssertFalse(self.push.userPushNotificationsEnabled,
                   @"userPushNotificationsEnabled should be disabled when set to NO");
    XCTAssertNoThrow([self.mockPushRegistration verify], @"[UAAPNSRegistration updateRegistrationWithOptions:categories:completionHandler:] should not be called");
}

/**
 * Test enabling or disabling backgroundPushNotificationsEnabled saves its settings
 * to NSUserDefaults and triggers a channel registration update.
 */
- (void)testBackgroundPushNotificationsEnabled {
    self.push.backgroundPushNotificationsEnabled = YES;

    XCTAssertTrue(self.testChannel.updateRegistrationCalled);

    self.testChannel.updateRegistrationCalled = NO;

    self.push.backgroundPushNotificationsEnabled = NO;

    XCTAssertTrue(self.testChannel.updateRegistrationCalled);
}

/**
 * Test enabling extended user notification permission saves its settings
 * to NSUserDefaults and updates apns registration.
 */
- (void)testExtendedPushNotificationPermissionEnabled {
    // SETUP
    self.push.userPushNotificationsEnabled = NO;

    // EXPECTATIONS
    UANotificationOptions expectedOptions = UANotificationOptionAlert | UANotificationOptionBadge | UANotificationOptionSound;
    [self expectUpdatePushRegistrationWithOptions:expectedOptions categories:self.push.combinedCategories];

    // TEST
    self.push.userPushNotificationsEnabled = YES;
    self.push.extendedPushNotificationPermissionEnabled = YES;

    // VERIFY
    XCTAssertTrue(self.push.extendedPushNotificationPermissionEnabled,
                  @"extendedPushNotificationPermissionEnabled should be enabled when set to YES");

    XCTAssertNoThrow([self.mockPushRegistration verify], @"[UAAPNSRegistration updateRegistrationWithOptions:categories:completionHandler:] should be called");
}

- (void)testExtendedPushNotificationPermissionEnabledWithUserNotificationsDisabled {
    // SETUP
    self.push.userPushNotificationsEnabled = NO;

    // EXPECTATIONS
    [self rejectUpdatePushRegistrationWithOptions];

    // TEST
    self.push.extendedPushNotificationPermissionEnabled = YES;

    // VERIFY
    XCTAssertFalse(self.push.extendedPushNotificationPermissionEnabled,
                  @"extendedPushNotificationPermissionEnabled should not be enabled when userNotificationsEnabled is set to NO");

    XCTAssertNoThrow([self.mockPushRegistration verify], @"[UAAPNSRegistration updateRegistrationWithOptions:categories:completionHandler:] should not be called");
}


- (void)testExtendedPushNotificationPermissionDisabled {
    // SETUP
    self.push.userPushNotificationsEnabled = NO;

    // EXPECTATIONS
    [self rejectUpdatePushRegistrationWithOptions];

    // TEST
    self.authorizationStatus = UAAuthorizationStatusEphemeral;
    self.push.userPushNotificationsEnabled = YES;

    // VERIFY
    XCTAssertFalse(self.push.extendedPushNotificationPermissionEnabled,
                  @"extendedPushNotificationPermissionEnabled should not be enabled when userNotificationsEnabled is set to NO");

    XCTAssertNoThrow([self.mockPushRegistration verify], @"[UAAPNSRegistration updateRegistrationWithOptions:categories:completionHandler:] should not be called");
}

- (void)testSetQuietTime {
    [self.push setQuietTimeStartHour:12 startMinute:30 endHour:14 endMinute:58];

    NSDictionary *quietTime = self.push.quietTime;
    XCTAssertEqualObjects(@"12:30", [quietTime valueForKey:UAPush.quietTimeStartKey],
                          @"Quiet time start is not set correctly");

    XCTAssertEqualObjects(@"14:58", [quietTime valueForKey:UAPush.quietTimeEndKey],
                          @"Quiet time end is not set correctly");

    // Change the time zone
    self.push.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:-3600*3];

    // Make sure the hour and minutes are still the same
    quietTime = self.push.quietTime;
    XCTAssertEqualObjects(@"12:30", [quietTime valueForKey:UAPush.quietTimeStartKey],
                          @"Quiet time start is not set correctly");

    XCTAssertEqualObjects(@"14:58", [quietTime valueForKey:UAPush.quietTimeEndKey],
                          @"Quiet time end is not set correctly");


    // Try to set it to an invalid start hour
    [self.push setQuietTimeStartHour:24 startMinute:30 endHour:14 endMinute:58];

    // Make sure the hour and minutes are still the same
    quietTime = self.push.quietTime;
    XCTAssertEqualObjects(@"12:30", [quietTime valueForKey:UAPush.quietTimeStartKey],
                          @"Quiet time start is not set correctly");

    XCTAssertEqualObjects(@"14:58", [quietTime valueForKey:UAPush.quietTimeEndKey],
                          @"Quiet time end is not set correctly");

    // Try to set it to an invalid end minute
    [self.push setQuietTimeStartHour:12 startMinute:30 endHour:14 endMinute:60];

    // Make sure the hour and minutes are still the same
    quietTime = self.push.quietTime;
    XCTAssertEqualObjects(@"12:30", [quietTime valueForKey:UAPush.quietTimeStartKey],
                          @"Quiet time start is not set correctly");

    XCTAssertEqualObjects(@"14:58", [quietTime valueForKey:UAPush.quietTimeEndKey],
                          @"Quiet time end is not set correctly");
}


- (void)testTimeZone {
    self.push.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"EST"];

    XCTAssertEqualObjects([NSTimeZone timeZoneWithAbbreviation:@"EST"],
                          self.push.timeZone,
                          @"timezone is not being set correctly");

    self.push.timeZone = nil;

    XCTAssertEqualObjects([NSTimeZone defaultTimeZone], self.push.timeZone);
}

/**
 * Test enable push notifications updates APNS registration and receives a completion handler callback.
 */
- (void)testEnablePushNotificationsCompletionHandlerCalled {
    self.push.customCategories = [NSSet set];
    self.push.notificationOptions = UANotificationOptionAlert;
    self.authorizedNotificationSettings = UAAuthorizedNotificationSettingsAlert;

    // EXPECTATIONS
    [self expectUpdatePushRegistrationWithOptions:self.push.notificationOptions categories:self.push.combinedCategories];

    XCTestExpectation *delegateCalled = [self expectationWithDescription:@"Delegate called"];
    XCTestExpectation *completionHandlerCalled = [self expectationWithDescription:@"Enable push completion handler called"];
    [[[self.mockRegistrationDelegate expect] andDo:^(NSInvocation *invocation) {
        [delegateCalled fulfill];
    }]  notificationRegistrationFinishedWithAuthorizedSettings:self.authorizedNotificationSettings categories:[OCMArg checkWithBlock:^BOOL(id obj) {
        NSSet *categories = (NSSet *)obj;
        return (categories.count == self.push.combinedCategories.count);
    }] status:UAAuthorizationStatusAuthorized];

    // TEST
    [self.push enableUserPushNotifications:^(BOOL success) {
        [completionHandlerCalled fulfill];
    }];

    // VERIFY
    [self waitForTestExpectations];
    XCTAssertNoThrow([self.mockPushRegistration verify], @"[UAAPNSRegistration updateRegistrationWithOptions:categories:completionHandler:] should be called");
    XCTAssertNoThrow([self.mockRegistrationDelegate verify], @"Registration delegate should be called");
}

- (void)testEnablePushNotificationsCompletionHandlerCalledWhenAppIsHandlingAuthorization {
    // SETUP
    self.config.requestAuthorizationToUseNotifications = NO;
    [self createPush];

    self.push.customCategories = [NSSet set];
    self.push.notificationOptions = UANotificationOptionAlert;
    self.authorizedNotificationSettings = UAAuthorizedNotificationSettingsAlert;

    // EXPECTATIONS
    [self rejectUpdatePushRegistrationWithOptions];

    XCTestExpectation *delegateCalled = [self expectationWithDescription:@"Delegate called"];
    XCTestExpectation *completionHandlerCalled = [self expectationWithDescription:@"Enable push completion handler called"];
    [[[self.mockRegistrationDelegate expect] andDo:^(NSInvocation *invocation) {
        [delegateCalled fulfill];
    }]  notificationRegistrationFinishedWithAuthorizedSettings:self.authorizedNotificationSettings categories:[OCMArg checkWithBlock:^BOOL(id obj) {
        NSSet *categories = (NSSet *)obj;
        return (categories.count == self.push.combinedCategories.count);
    }] status:UAAuthorizationStatusAuthorized];

    // TEST
    [self.push enableUserPushNotifications:^(BOOL success) {
        [completionHandlerCalled fulfill];
    }];

    // VERIFY
    [self waitForExpectationsWithTimeout:1 handler:nil];
    XCTAssertNoThrow([self.mockPushRegistration verify], @"[UAAPNSRegistration updateRegistrationWithOptions:categories:completionHandler:] should not be called");
    XCTAssertNoThrow([self.mockRegistrationDelegate verify], @"Registration delegate should be called");
}

/**
 * Test setting authorized types to a new type results in a call to the registration delegate
 */
-(void)testSetAuthorizedTypesCallsRegistrationDelegate {

    UAAuthorizedNotificationSettings expectedSettings = 2;

    XCTestExpectation *delegateCalled = [self expectationWithDescription:@"Delegate called"];

    [[[self.mockRegistrationDelegate expect] andDo:^(NSInvocation *invocation) {
        [delegateCalled fulfill];
    }]  notificationAuthorizedSettingsDidChange:expectedSettings];

    // set authorized types
    self.authorizedNotificationSettings = expectedSettings;
    [LegacyPushTestUtils updateAuthorizedNotificationTypesWithPush:self.push];

    [self waitForTestExpectations];

    XCTAssertNoThrow([self.mockRegistrationDelegate verify]);
}

/**
 * Test receiving a call to application:didRegisterForRemoteNotificationsWithDeviceToken: results in that call being forwarded to the registration delegate
 */
-(void)testPushForwardsDidRegisterForRemoteNotificationsWithDeviceTokenToRegistrationDelegateForeground {
    XCTestExpectation *delegateCalled = [self expectationWithDescription:@"Registration delegate called"];

    [[[self.mockRegistrationDelegate expect] andDo:^(NSInvocation *invocation) {
        [delegateCalled fulfill];
    }]  apnsRegistrationSucceededWithDeviceToken:self.validAPNSDeviceToken];

    // TEST
    [self setDeviceToken:self.validAPNSDeviceToken];
    
    // VERIFY
    [self waitForTestExpectations];

    [self.mockRegistrationDelegate verify];

    // device token also should be set
    XCTAssertTrue([self.push.deviceToken isEqualToString:[UAUtils deviceTokenStringFromDeviceToken:self.validAPNSDeviceToken]]);

    XCTAssertTrue(self.testChannel.updateRegistrationCalled);
}

/**
 * Test receiving a call to application:didRegisterForRemoteNotificationsWithDeviceToken: results in that call being forwarded to the registration delegate
 */
-(void)testPushForwardsDidRegisterForRemoteNotificationsWithDeviceTokenToRegistrationDelegateBackground {
    self.testAppStateTracker.currentState =  UAApplicationStateBackground;

    // EXPECTATIONS
    [[self.mockRegistrationDelegate expect] apnsRegistrationSucceededWithDeviceToken:self.validAPNSDeviceToken];

    // TEST
    [self setDeviceToken:self.validAPNSDeviceToken];
    
    // VERIFY
    XCTAssertTrue([self.push.deviceToken isEqualToString:[UAUtils deviceTokenStringFromDeviceToken:self.validAPNSDeviceToken]]);

    [self.mockRegistrationDelegate verify];
    XCTAssertTrue(self.testChannel.updateRegistrationCalled);
}

/**
 * Test receiving a call to application:didFailToRegisterForRemoteNotificationsWithError: results in that call being forwarded to the registration delegate
 */
-(void)testPushForwardsDidFailToRegisterForRemoteNotificationsWithDeviceTokenToRegistrationDelegate {
    NSError *error = [NSError errorWithDomain:@"domain" code:100 userInfo:nil];

    XCTestExpectation *delegateCalled = [self expectationWithDescription:@"Registration delegate called"];

    [[[self.mockRegistrationDelegate expect] andDo:^(NSInvocation *invocation) {
        [delegateCalled fulfill];
    }]  apnsRegistrationFailedWithError:error];

    
    [LegacyPushTestUtils didFailToRegisterForRemoteNotificationsWithPush:self.push error:error];

    [self waitForTestExpectations];

    XCTAssertNoThrow([self.mockRegistrationDelegate verify]);
}

/**
 * Test setting requireAuthorizationForDefaultCategories requests the correct
 * defaults user notification categories.
 */
- (void)testRequireAuthorizationForDefaultCategories {
    // Clear the custom categories so we can check only Airship categories in comibinedCategories.
    self.push.customCategories = [NSSet set];

    XCTAssertTrue(self.push.combinedCategories.count);

    self.push.requireAuthorizationForDefaultCategories = YES;
    for (UNNotificationCategory *category in self.push.combinedCategories) {
        for (UNNotificationAction *action in category.actions) {
            // Only check background actions
            if ((action.options & UNNotificationActionOptionForeground) == UANotificationOptionNone) {
                XCTAssertTrue((action.options & UNNotificationActionOptionAuthenticationRequired) > 0, @"Invalid options for action: %@", action.identifier);

            }
        }
    }

    self.push.requireAuthorizationForDefaultCategories = NO;
    for (UNNotificationCategory *category in self.push.combinedCategories) {
        for (UNNotificationAction *action in category.actions) {
            // Only check background actions
            if ((action.options & UNNotificationActionOptionForeground) == UANotificationOptionNone) {
                XCTAssertFalse((action.options & UNNotificationActionOptionAuthenticationRequired) > 0, @"Invalid options for action: %@", action.identifier);

            }
        }
    }
}

/**
 * Test the user notification categories used to register is the union between
 * the default categories and the custom categories.
 */
- (void)testNotificationCategories {
    self.push.userPushNotificationsEnabled = YES;

    UNNotificationCategory *customCategory = [UNNotificationCategory categoryWithIdentifier:@"customCategory" actions:@[]  intentIdentifiers:@[] options:UNNotificationCategoryOptionNone];
    UNNotificationCategory *anotherCustomCategory = [UNNotificationCategory categoryWithIdentifier:@"anotherCustomCategory" actions:@[] intentIdentifiers:@[] options:UNNotificationCategoryOptionNone];

    NSSet *defaultSet = [UANotificationCategories defaultCategoriesWithRequireAuth:self.push.requireAuthorizationForDefaultCategories];

    NSSet *customSet = [NSSet setWithArray:@[customCategory, anotherCustomCategory]];
    self.push.customCategories = customSet;

    NSMutableSet *combinedSet = [[NSMutableSet alloc] init];
    [combinedSet unionSet:customSet];
    [combinedSet unionSet:defaultSet];

    XCTAssertEqualObjects(self.push.combinedCategories, combinedSet);
}

- (void)testSetBadgeNumberAutoBadgeEnabled {
    // Set the right values so we can check if a device api client call was made or not
    self.push.userPushNotificationsEnabled = YES;
    self.push.autobadgeEnabled = YES;
    [self setDeviceToken:self.validAPNSDeviceToken];

    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSInteger)30)] applicationIconBadgeNumber];

    // EXPECTATIONS
    [[self.mockApplication expect] setApplicationIconBadgeNumber:15];

    // TEST
    [self.push setBadgeNumber:15];

    // VERIFY
    XCTAssertNoThrow([self.mockApplication verify],
                     @"should update application icon badge number when its different");

    XCTAssertTrue(self.testChannel.updateRegistrationCalled);
}

- (void)testSetBadgeNumberNoChange {
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSInteger)30)] applicationIconBadgeNumber];
    [[self.mockApplication reject] setApplicationIconBadgeNumber:30];

    [self.push setBadgeNumber:30];
    XCTAssertNoThrow([self.mockApplication verify],
                     @"should not update application icon badge number if there is no change");
}

- (void)testSetBadgeNumberAutoBadgeDisabled {
    self.push.userPushNotificationsEnabled = YES;
    [self setDeviceToken:self.validAPNSDeviceToken];

    self.push.autobadgeEnabled = NO;

    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSInteger)30)] applicationIconBadgeNumber];
    [[self.mockApplication expect] setApplicationIconBadgeNumber:15];

    self.testChannel.updateRegistrationCalled = NO;

    [self.push setBadgeNumber:15];
    XCTAssertNoThrow([self.mockApplication verify],
                     @"should update application icon badge number when its different");

    XCTAssertFalse(self.testChannel.updateRegistrationCalled);
}

- (void)testResetBadge {
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSInteger)30)] applicationIconBadgeNumber];
    [[self.mockApplication expect] setApplicationIconBadgeNumber:0];

    [self.push resetBadge];
    XCTAssertNoThrow([self.mockApplication verify],
                     @"should set application icon badge number to 0");
}

- (void)testResetBadgeNumberNoChange {
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSInteger)0)] applicationIconBadgeNumber];
    [[self.mockApplication reject] setApplicationIconBadgeNumber:0];

    [self.push resetBadge];
    XCTAssertNoThrow([self.mockApplication verify],
                     @"should not update application icon badge number if there is no change");
}

- (void)testApplicationDidTransitionToForegroundWhenAppIsHandlingAuthorization {
    // SETUP
    self.config.requestAuthorizationToUseNotifications = NO;
    [self createPush];

    self.push.userPushNotificationsEnabled = YES;
    self.push.notificationOptions = UANotificationOptionAlert;

    self.authorizedNotificationSettings = UAAuthorizedNotificationSettingsAlert;
    UAAuthorizedNotificationSettings expectedSettings = UAAuthorizedNotificationSettingsAlert;

    [self rejectUpdatePushRegistrationWithOptions];

    // TEST
    [self.notificationCenter postNotificationName:UAAppStateTracker.didTransitionToForeground object:nil];

    // VERIFY
    XCTAssertTrue(self.push.userPromptedForNotifications);
    XCTAssertEqual(self.push.authorizedNotificationSettings, expectedSettings);

    XCTAssertTrue(self.testChannel.updateRegistrationCalled);
    XCTAssertNoThrow([self.mockPushRegistration verify], @"[UAAPNSRegistration updateRegistrationWithOptions:categories:completionHandler:] should not be called");
}

- (void)testApplicationBackgroundRefreshStatusChangedBackgroundAvailable {
    // SETUP
    [[[self.mockApplication stub] andReturnValue:@(UIBackgroundRefreshStatusAvailable)] backgroundRefreshStatus];

    // EXPECTATIONS
    [[self.mockApplication expect] registerForRemoteNotifications];

    // TEST
    [self.notificationCenter postNotificationName:UIApplicationBackgroundRefreshStatusDidChangeNotification object:nil];

    // VERIFY
    XCTAssertNoThrow([self.mockApplication verify], @"[UIApplication registerForRemoteNotifications] should be called");
}

- (void)testApplicationBackgroundRefreshStatusChangedBackgroundDenied {
    [[[self.mockApplication stub] andReturnValue:@(UIBackgroundRefreshStatusDenied)] backgroundRefreshStatus];

    [self.notificationCenter postNotificationName:UIApplicationBackgroundRefreshStatusDidChangeNotification object:nil];

    XCTAssertTrue(self.testChannel.updateRegistrationCalled);
}

-(void)testApplicationBackgroundRefreshStatusChangedBackgroundDeniedWhenAppIsHandlingAuthorization {
    // SETUP
    self.config.requestAuthorizationToUseNotifications = NO;
    [self createPush];

    [[[self.mockApplication stub] andReturnValue:@(UIBackgroundRefreshStatusDenied)] backgroundRefreshStatus];
    // set an option so channel registration happens
    self.push.notificationOptions = UANotificationOptionSound;
    self.authorizedNotificationSettings = UAAuthorizedNotificationSettingsSound;

    // EXPECTATIONS
    [self rejectUpdatePushRegistrationWithOptions];

    // TEST
    [self.notificationCenter postNotificationName:UIApplicationBackgroundRefreshStatusDidChangeNotification object:nil];

    // VERIFY
    XCTAssertNoThrow([self.mockPushRegistration verify], @"[UAAPNSRegistration updateRegistrationWithOptions:categories:completionHandler:] should not be called");
}

/**
 * Test applicationDidEnterBackground clears the notification.
 */
- (void)testApplicationDidEnterBackground {
    id response = [self mockForClass:[UNTextInputNotificationResponse class]];
    [[[response stub] andReturn:self.mockUNNotification] notification];
    [[[response stub] andReturn:UNNotificationDefaultActionIdentifier] actionIdentifier];
    [[[response stub] andReturn:@"test_response_text"] userText];

    [LegacyPushTestUtils didReceiveNotificationResponseWithPush:self.push
                                                       response:response
                                              completionHandler:^{}];
  
    [self.notificationCenter postNotificationName:UAAppStateTracker.didEnterBackgroundNotification object:nil];

    XCTAssertNil(self.push.launchNotificationResponse, @"applicationDidEnterBackground should clear the launch notification");
}

- (void)testmigratePushTagsToChannelTags {
    [self.dataStore setObject:@[@"cool", @"rad"] forKey:UAPush.legacyTagsSettingsKey];

    NSArray *expectedTags = @[@"cool", @"rad"];

    // Force a migration
    [self.dataStore removeObjectForKey:UAPush.tagsMigratedToChannelTagsKey];

    [self.push migratePushTagsToChannelTags];

    XCTAssertEqualObjects(self.testChannel.tags, expectedTags);
    XCTAssertTrue([self.dataStore boolForKey:UAPush.tagsMigratedToChannelTagsKey]);
    XCTAssertNil([self.dataStore objectForKey:UAPush.legacyTagsSettingsKey]);
}

- (void)testMigratePushTagsToChannelTagsCombined {
    [self.dataStore setObject:@[@"cool", @"rad"] forKey:UAPush.legacyTagsSettingsKey];

    self.testChannel.tags = @[@"not cool", @"not rad"];

    // Force a migration
    [self.dataStore removeObjectForKey:UAPush.tagsMigratedToChannelTagsKey];

    [self.push migratePushTagsToChannelTags];

    XCTAssertTrue([self.dataStore boolForKey:UAPush.tagsMigratedToChannelTagsKey]);
    XCTAssertNil([self.dataStore objectForKey:UAPush.legacyTagsSettingsKey]);

    NSArray *expected = @[@"cool", @"rad", @"not cool", @"not rad"];
    XCTAssertEqualObjects([NSSet setWithArray:self.testChannel.tags], [NSSet setWithArray:expected]);
}

- (void)testMigratePushTagsToChannelTagsAlreadyMigrated {
    self.testChannel.tags = @[@"some-random-value"];
    [self.dataStore setBool:YES forKey:UAPush.tagsMigratedToChannelTagsKey];
    [self.push migratePushTagsToChannelTags];

    XCTAssertEqualObjects(self.testChannel.tags, @[@"some-random-value"]);
}

/**
 * Test handleRemoteNotification when auto badge is disabled does
 * not set the badge on the application
 */
- (void)testHandleNotificationAutoBadgeDisabled {
    self.push.autobadgeEnabled = NO;
    [[self.mockApplication reject] setApplicationIconBadgeNumber:2];

    
    // TEST
    [LegacyPushTestUtils didReceiveRemoteNotificationWithPush:self.push
                                                     userInfo:self.notification
                                                 isForeground:YES
                                            completionHandler:^(UIBackgroundFetchResult result) {}];
    
    [LegacyPushTestUtils didReceiveRemoteNotificationWithPush:self.push
                                                     userInfo:self.notification
                                                 isForeground:NO
                                            completionHandler:^(UIBackgroundFetchResult result) {}];
    
    // VERIFY
    XCTAssertNoThrow([self.mockApplication verify]);
}

/**
 * Test handleRemoteNotification when auto badge is enabled sets the badge
 * only when a notification comes in while the app is in the foreground
 */
- (void)testHandleNotificationAutoBadgeEnabled {
    self.push.autobadgeEnabled = YES;

    [[self.mockApplication expect] setApplicationIconBadgeNumber:2];
    [LegacyPushTestUtils didReceiveRemoteNotificationWithPush:self.push
                                                     userInfo:self.notification
                                                 isForeground:YES
                                            completionHandler:^(UIBackgroundFetchResult result) {}];
    
    
    XCTAssertNoThrow([self.mockApplication verify], @"[UIApplication setApplicationIconBadgeNumber] should be called");

    [[self.mockApplication reject] setApplicationIconBadgeNumber:2];
    
    [LegacyPushTestUtils didReceiveRemoteNotificationWithPush:self.push
                                                     userInfo:self.notification
                                                 isForeground:NO
                                            completionHandler:^(UIBackgroundFetchResult result) {}];
    XCTAssertNoThrow([self.mockApplication verify], @"[UIApplication setApplicationIconBadgeNumber] should not be called");
}

/**
 * Test handleNotificationResponse sets the launched notificaitno response if
 * its the default identifier.
 */
- (void)testHandleNotificationLaunchNotification {
    id response = [self mockForClass:[UNNotificationResponse class]];
    [[[response stub] andReturn:self.mockUNNotification] notification];
    [[[response stub] andReturn:UNNotificationDefaultActionIdentifier] actionIdentifier];

    [LegacyPushTestUtils didReceiveNotificationResponseWithPush:self.push response:response completionHandler:^{}];

    XCTAssertEqual(self.push.launchNotificationResponse, response);
}

/**
 * Test handleRemoteNotification when foreground and autobadge is enabled.
 */
- (void)testHandleRemoteNotificationForegroundAutobadgeEnabled {
    self.push.autobadgeEnabled = YES;

    // Application should set icon badge number when autobadge is enabled
    [[self.mockApplication expect] setApplicationIconBadgeNumber:2];

    __block NSNotification *notification;

    XCTestExpectation *notificationFired = [self expectationWithDescription:@"Notification event fired"];
    [self.notificationCenter addObserverForName:UAPush.receivedForegroundNotificationEvent object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        notification = note;
        [notificationFired fulfill];
    }];

    [[self.mockPushDelegate expect] receivedForegroundNotification:self.notification completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^handler)(void) = obj;
        handler();
        return YES;
    }]];

    [[self.mockPushDelegate reject] receivedBackgroundNotification:self.notification completionHandler:OCMOCK_ANY];

    XCTestExpectation *completionHandlerCalledExpectation = [self expectationWithDescription:@"handleRemoteNotification completionHandler should be called"];

    // TEST
    [LegacyPushTestUtils didReceiveRemoteNotificationWithPush:self.push
                                                     userInfo:self.notification
                                                 isForeground:YES
                                            completionHandler:^(UIBackgroundFetchResult result) {
        [completionHandlerCalledExpectation fulfill];
    }];
    

    // VERIFY
    [self waitForTestExpectations];

    XCTAssertEqualObjects(self.notification, notification.userInfo);

    [self.mockApplication verify];
    [self.mockPushDelegate verify];
}

/**
 * Test handleRemoteNotification when foreground and autobadge is disabled.
 */
- (void)testHandleRemoteNotificationForegroundAutobadgeDisabled {
    self.push.autobadgeEnabled = NO;

    // Application should set icon badge number when autobadge is enabled
    [[self.mockApplication reject] setApplicationIconBadgeNumber:2];

    __block NSNotification *notification;

    XCTestExpectation *notificationFired = [self expectationWithDescription:@"Notification event fired"];
    [self.notificationCenter addObserverForName:UAPush.receivedForegroundNotificationEvent object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        notification = note;
        [notificationFired fulfill];
    }];

    [[self.mockPushDelegate expect] receivedForegroundNotification:self.notification completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^handler)(void) = obj;
        handler();
        return YES;
    }]];

    [[self.mockPushDelegate reject] receivedBackgroundNotification:self.notification completionHandler:OCMOCK_ANY];

    XCTestExpectation *completionHandlerCalledExpectation = [self expectationWithDescription:@"handleRemoteNotification completionHandler should be called"];

    // TEST
    
    [LegacyPushTestUtils didReceiveRemoteNotificationWithPush:self.push
                                                     userInfo:self.notification
                                                 isForeground:YES
                                            completionHandler:^(UIBackgroundFetchResult result) {
        [completionHandlerCalledExpectation fulfill];
    }];
    
    // VERIFY
    [self waitForTestExpectations];

    XCTAssertEqualObjects(self.notification, notification.userInfo);

    [self.mockApplication verify];
    XCTAssertNoThrow([self.mockPushDelegate verify], @"push delegate should be called");
}

/**
 * Test handleRemoteNotification when background push.
 */
- (void)testHandleRemoteNotificationBackground {
    __block NSNotification *notification;

    XCTestExpectation *notificationFired = [self expectationWithDescription:@"Notification event fired"];
    [self.notificationCenter addObserverForName:UAPush.receivedBackgroundNotificationEvent object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        notification = note;
        [notificationFired fulfill];
    }];

    [[self.mockPushDelegate reject] receivedForegroundNotification:self.notification completionHandler:OCMOCK_ANY];

    [[self.mockPushDelegate expect] receivedBackgroundNotification:self.notification completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^handler)(void) = obj;
        handler();
        return YES;
    }]];

    XCTestExpectation *completionHandlerCalledExpectation = [self expectationWithDescription:@"handleRemoteNotification completionHandler should be called"];

    // TEST
    [LegacyPushTestUtils didReceiveRemoteNotificationWithPush:self.push
                                                     userInfo:self.notification
                                                 isForeground:NO
                                            completionHandler:^(UIBackgroundFetchResult result) {
        [completionHandlerCalledExpectation fulfill];
    }];
    
    // VERIFY
    [self waitForTestExpectations];

    XCTAssertEqualObjects(self.notification, notification.userInfo);
    XCTAssertNoThrow([self.mockPushDelegate verify], @"push delegate should be called");
}

/**
 * Test handleRemoteNotification when no delegate is set.
 */
- (void)testHandleRemoteNotificationNoDelegate {
    self.push.pushNotificationDelegate = nil;

    XCTestExpectation *completionHandlerCalledExpectation = [self expectationWithDescription:@"handleRemoteNotification completionHandler should be called"];

    __block NSNotification *notification;

    XCTestExpectation *notificationFired = [self expectationWithDescription:@"Notification event fired"];
    [self.notificationCenter addObserverForName:UAPush.receivedForegroundNotificationEvent object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        notification = note;
        [notificationFired fulfill];
    }];

    // TEST
    [LegacyPushTestUtils didReceiveRemoteNotificationWithPush:self.push
                                                     userInfo:self.notification
                                                 isForeground:YES
                                            completionHandler:^(UIBackgroundFetchResult result) {
        [completionHandlerCalledExpectation fulfill];
        XCTAssertEqual(result, UIBackgroundFetchResultNoData);
    }];
    

    // VERIFY
    [self waitForTestExpectations];
    XCTAssertEqualObjects(self.notification, notification.userInfo);
}

/**
 * Test handleNotificationResponse when launched from push.
 */
- (void)testHandleNotificationResponseLaunchedFromPush {
    id response = [self mockForClass:[UNTextInputNotificationResponse class]];
    [[[response stub] andReturn:self.mockUNNotification] notification];
    [[[response stub] andReturn:UNNotificationDefaultActionIdentifier] actionIdentifier];
    [[[response stub] andReturn:@"test_response_text"] userText];

    // delegate needs to be unresponsive to receivedNotificationResponse callback
    self.push.pushNotificationDelegate = nil;

    __block NSNotification *notification;

    XCTestExpectation *notificationFired = [self expectationWithDescription:@"Notification event fired"];
    [self.notificationCenter addObserverForName:UAPush.receivedNotificationResponseEvent object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        notification = note;
        [notificationFired fulfill];
    }];

    // Call handleNotificationResponse
    [LegacyPushTestUtils didReceiveNotificationResponseWithPush:self.push
                                                       response:response
                                              completionHandler:^{}];
    
    [self waitForTestExpectations];

    // Check that the launchNotificationReponse is set to expected response
    XCTAssertEqualObjects(self.push.launchNotificationResponse, response);
}

/**
 * Test handleNotificationResponse when not launched from push.
 */
- (void)testHandleNotificationResponseNotLaunchedFromPush {
    id response = [self mockForClass:[UNTextInputNotificationResponse class]];
    [[[response stub] andReturn:self.mockUNNotification] notification];
    [[[response stub] andReturn:@"test_action_identifier"] actionIdentifier];
    [[[response stub] andReturn:@"test_response_text"] userText];

    [[self.mockPushDelegate expect] receivedNotificationResponse:OCMOCK_ANY completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^handler)(void) = obj;
        handler();
        return YES;
    }]];

    XCTestExpectation *completionHandlerCalledExpectation = [self expectationWithDescription:@"handleRemoteNotification completionHandler should be called"];

    __block NSNotification *notification;

    XCTestExpectation *notificationFired = [self expectationWithDescription:@"Notification event fired"];
    [self.notificationCenter addObserverForName:UAPush.receivedNotificationResponseEvent object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        notification = note;
        [notificationFired fulfill];
    }];

    // TEST
    [LegacyPushTestUtils didReceiveNotificationResponseWithPush:self.push
                                                       response:response
                                              completionHandler:^{
        [completionHandlerCalledExpectation fulfill];
    }];
    
    // VERIFY
    [self waitForTestExpectations];
    XCTAssertNil(self.push.launchNotificationResponse);
    XCTAssertNoThrow([self.mockPushDelegate verify], @"push delegate should be called");
    XCTAssertEqualObjects(response, notification.userInfo[UAPush.receivedNotificationResponseEventResponseKey]);
}

/**
 * Test handleNotificationResponse no delegate set.
 */
- (void)testHandleNotificationResponse {
    self.push.pushNotificationDelegate = nil;

    id response = [self mockForClass:[UNTextInputNotificationResponse class]];
    [[[response stub] andReturn:self.mockUNNotification] notification];
    [[[response stub] andReturn:@"test_action_identifier"] actionIdentifier];
    [[[response stub] andReturn:@"test_response_text"] userText];

    XCTestExpectation *completionHandlerCalledExpectation = [self expectationWithDescription:@"handleRemoteNotification completionHandler should be called"];

    // TEST
    [LegacyPushTestUtils didReceiveNotificationResponseWithPush:self.push
                                                       response:response
                                              completionHandler:^{
        [completionHandlerCalledExpectation fulfill];
    }];
    
    // VERIFY
    [self waitForTestExpectations];
    XCTAssertNil(self.push.launchNotificationResponse);
}

/**
 * Test presentationOptionsForNotification when delegate method is unimplemented.
 */
- (void)testPresentationOptionsForNotificationNoDelegate {

    self.push.defaultPresentationOptions = UNNotificationPresentationOptionAlert;

    if (@available(iOS 14.0, tvOS 14.0, *)) {
        self.push.defaultPresentationOptions = UNNotificationPresentationOptionList | UNNotificationPresentationOptionBanner;
    }

    self.push.pushNotificationDelegate = nil;

    UNNotificationPresentationOptions result = [LegacyPushTestUtils presentationOptionsWithPush:self.push notification:self.mockUNNotification];
    
    XCTAssertEqual(result, self.push.defaultPresentationOptions);
}

/**
 * Test presentationOptionsForNotification when delegate method is implemented.
 */
- (void)testPresentationOptionsForNotification {
    if (@available(iOS 14.0, *)) {
        [[[self.mockPushDelegate stub] andReturnValue:OCMOCK_VALUE(UNNotificationPresentationOptionList | UNNotificationPresentationOptionBanner)] extendPresentationOptions:UNNotificationPresentationOptionNone notification:self.mockUNNotification];
    } else {
        [[[self.mockPushDelegate stub] andReturnValue:OCMOCK_VALUE(UNNotificationPresentationOptionAlert)] extendPresentationOptions:UNNotificationPresentationOptionNone notification:self.mockUNNotification];
    }

    
    UNNotificationPresentationOptions result = [LegacyPushTestUtils presentationOptionsWithPush:self.push notification:self.mockUNNotification];

    if (@available(iOS 14.0, *)) {
        XCTAssertEqual(result, UNNotificationPresentationOptionList | UNNotificationPresentationOptionBanner);
    } else {
        XCTAssertEqual(result, UNNotificationPresentationOptionAlert);
    }
}

/**
 * Test presentationOptionsForNotification when notification contains foreground options and delegate method is unimplemented.
 */
- (void)testPresentationOptionsForNotificationWithForegroundOptionsWithoutDelegate {
    // SETUP
    NSArray *array = @[@"alert", @"sound", @"badge"];

    if (@available(iOS 14.0, *)) {
        array = @[@"list", @"banner", @"sound", @"badge"];
    }

    self.mockUserInfo[@"com.urbanairship.foreground_presentation"] = array;

    self.push.pushNotificationDelegate = nil;

    // EXPECTATIONS
    UNNotificationPresentationOptions options = UNNotificationPresentationOptionAlert | UNNotificationPresentationOptionSound | UNNotificationPresentationOptionBadge;

    if (@available(iOS 14.0, *)) {
        options = UNNotificationPresentationOptionList | UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionSound | UNNotificationPresentationOptionBadge;
    }

    // TEST
    UNNotificationPresentationOptions result = [LegacyPushTestUtils presentationOptionsWithPush:self.push notification:self.mockUNNotification];
    
    // VERIFY
    XCTAssertEqual(result, options);
}

/**
 * Test presentationOptionsForNotification when notification foreground options array is empty and delegate method is unimplemented.
 */
- (void)testPresentationOptionsForNotificationWithoutForegroundOptionsWithoutDelegate {
    // SETUP
    self.mockUserInfo[@"com.urbanairship.foreground_presentation"] = @[];

    self.push.defaultPresentationOptions = UNNotificationPresentationOptionAlert;

    if (@available(iOS 14.0, *)) {
        self.push.defaultPresentationOptions = UNNotificationPresentationOptionList | UNNotificationPresentationOptionBanner;
    }

    self.push.pushNotificationDelegate = nil;

    // EXPECTATIONS
    UNNotificationPresentationOptions options = UNNotificationPresentationOptionAlert;

    if (@available(iOS 14.0, *)) {
        options = UNNotificationPresentationOptionList | UNNotificationPresentationOptionBanner;
    }

    // TEST
    UNNotificationPresentationOptions result = [LegacyPushTestUtils presentationOptionsWithPush:self.push notification:self.mockUNNotification];
    
    // VERIFY
    XCTAssertEqual(result, options);
}


/**
 * Test on first launch when user has not been prompted for notification.
 */
- (void)testNotificationNotPrompted {
    XCTAssertFalse(self.push.userPromptedForNotifications);
}

/**
 * Test registering a device token.
 */
- (void)testRegisteredDeviceToken {
    // SETUP
    self.testAppStateTracker.currentState = UAApplicationStateBackground;

    NSData *token = [@"some-token" dataUsingEncoding:NSASCIIStringEncoding];

    // TEST
    [self setDeviceToken:token];

    // VERIFY
    // Expect UAPush to receive the device token string
    // 736f6d652d746f6b656e = "some-token" in hex
    XCTAssertTrue([@"736f6d652d746f6b656e" isEqualToString:self.push.deviceToken]);

    XCTAssertTrue(self.testChannel.updateRegistrationCalled);
}

- (void)testDidRegisterForRemoteNotificationsWithDeviceTokenDoesntRegisterChannelWhenInBackground {
    self.testChannel.identifier = @"some-channel";
    // SETUP
    self.testAppStateTracker.currentState = UAApplicationStateBackground;

    self.testChannel.updateRegistrationCalled = NO;

    // TEST
    NSData *token = [@"some-token" dataUsingEncoding:NSASCIIStringEncoding];
    [self setDeviceToken:token];

    // VERIFY
    // Expect UAPush to receive the device token string
    // 736f6d652d746f6b656e = "some-token" in hex
    XCTAssertTrue([@"736f6d652d746f6b656e" isEqualToString:self.push.deviceToken]);

    XCTAssertFalse(self.testChannel.updateRegistrationCalled);
}

- (void)testEnablingDisabledPushUpdatesRegistration {
    // Setup
    self.testChannel.identifier = @"someChannelID";
    self.push.componentEnabled = NO;
    self.push.userPushNotificationsEnabled = YES;

    // EXPECTATIONS
    [self expectUpdatePushRegistrationWithOptions:self.push.notificationOptions categories:self.push.combinedCategories];

    // Test
    self.push.componentEnabled = YES;

    [self.mockPushRegistration verify];
}

- (void)testEnablingDisabledPushDoesNotUpdateRegistrationWhenAppIsHandlingAuthorization {
    // Setup
    self.config.requestAuthorizationToUseNotifications = NO;
    [self createPush];

    self.push.userPushNotificationsEnabled = YES;
    self.testChannel.identifier = @"someChannelID";
    self.push.componentEnabled = NO;

    // EXPECTATIONS
    [self rejectUpdatePushRegistrationWithOptions];

    // Test
    self.push.componentEnabled = YES;

    // verify
    [self.mockPushRegistration verify];
}

- (void)testUpdateAuthorizedNotificationTypesUpdatesChannelRegistrationWhenAppIsHandlingAuthorization {
    // SETUP
    self.config.requestAuthorizationToUseNotifications = NO;
    [self createPush];

    self.authorizedNotificationSettings = UAAuthorizedNotificationSettingsAlert | UAAuthorizedNotificationSettingsBadge;
    self.authorizationStatus = UAAuthorizationStatusAuthorized;

    // TEST
    [LegacyPushTestUtils updateAuthorizedNotificationTypesWithPush:self.push];

    // VERIFY
    XCTAssertTrue(self.testChannel.updateRegistrationCalled);
}

/**
 * Test registration payload.
 */
- (void)testRegistrationPayload {
    NSData *token = [@"some-token" dataUsingEncoding:NSASCIIStringEncoding];
    [self setDeviceToken:token];
    
    self.push.quietTimeEnabled = YES;
    self.push.timeZone = [NSTimeZone timeZoneWithName:@"Pacific/Auckland"];
    [self.push setQuietTimeStartHour:12 startMinute:30 endHour:14 endMinute:58];

    UAChannelRegistrationPayload *payload = [[UAChannelRegistrationPayload alloc] init];
    XCTestExpectation *extendedPayload = [self expectationWithDescription:@"extended payload"];
    [self.testChannel extendPayload:payload completionHandler:^(UAChannelRegistrationPayload * payload) {
        XCTAssertEqualObjects(@"736f6d652d746f6b656e", payload.channel.pushAddress);
        XCTAssertEqualObjects(self.push.quietTime[@"end"], payload.channel.iOSChannelSettings.quietTime.end);
        XCTAssertEqualObjects(self.push.quietTime[@"start"], payload.channel.iOSChannelSettings.quietTime.start);
        XCTAssertEqualObjects(@"Pacific/Auckland", payload.channel.iOSChannelSettings.quietTimeTimeZone);
        [extendedPayload fulfill];
    }];

    [self waitForTestExpectations];
}


- (void)testRegistrationPayloadQuietTimeDisabled {
    self.push.quietTimeEnabled = NO;
    self.push.timeZone = [NSTimeZone timeZoneWithName:@"Pacific/Auckland"];
    [self.push setQuietTimeStartHour:12 startMinute:30 endHour:14 endMinute:58];

    UAChannelRegistrationPayload *payload = [[UAChannelRegistrationPayload alloc] init];
    XCTestExpectation *extendedPayload = [self expectationWithDescription:@"extended payload"];
    [self.testChannel extendPayload:payload completionHandler:^(UAChannelRegistrationPayload * payload) {
        XCTAssertNil(payload.channel.iOSChannelSettings);
        [extendedPayload fulfill];
    }];

    [self waitForTestExpectations];
}

/**
 * Test disable token registration in the CRA payload.
 */
- (void)testRegistrationPayloadDisabledTokenRegistration {
    NSData *token = [@"some-token" dataUsingEncoding:NSASCIIStringEncoding];
    [self setDeviceToken:token];

    [self.privacyManager disableFeatures:UAFeaturesPush];

    UAChannelRegistrationPayload *payload = [[UAChannelRegistrationPayload alloc] init];
    XCTestExpectation *extendedPayload = [self expectationWithDescription:@"extended payload"];
    [self.testChannel extendPayload:payload completionHandler:^(UAChannelRegistrationPayload * payload) {
            XCTAssertNil(payload.channel.pushAddress);
            [extendedPayload fulfill];
    }];

    [self waitForTestExpectations];
}

/**
 * Test auto badge is added to the CRA payload.
 */
- (void)testRegistrationPayloadAutoBadgeEnabled {
    self.push.autobadgeEnabled = YES;
    [[[self.mockApplication stub] andReturnValue:@(30)] applicationIconBadgeNumber];

    UAChannelRegistrationPayload *payload = [[UAChannelRegistrationPayload alloc] init];
    XCTestExpectation *extendedPayload = [self expectationWithDescription:@"extended payload"];
    [self.testChannel extendPayload:payload completionHandler:^(UAChannelRegistrationPayload *payload) {
        XCTAssertEqualObjects(payload.channel.iOSChannelSettings.badgeNumber, @(30));
            [extendedPayload fulfill];
    }];

    [self waitForTestExpectations];
}

/**
 * A utility method that takes an APNS-provided device token and returns the decoded Airship device token
 */
- (NSString *)deviceTokenStringFromDeviceToken:(NSData *)deviceToken {
    NSMutableString *deviceTokenString = [NSMutableString stringWithCapacity:([deviceToken length] * 2)];
    const unsigned char *bytes = (const unsigned char *)[deviceToken bytes];

    for (NSUInteger i = 0; i < [deviceToken length]; i++) {
        [deviceTokenString appendFormat:@"%02X", bytes[i]];
    }

    return [deviceTokenString lowercaseString];
}

- (NSData *)dataFromHexString:(NSString *)string {
    string = [string stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSMutableData *out = [[NSMutableData alloc] init];
    unsigned char whole_byte;
    char byte_chars[3] = {'\0','\0','\0'};
    for (int i=0; i < [string length]/2; i++) {
        byte_chars[0] = [string characterAtIndex:i*2];
        byte_chars[1] = [string characterAtIndex:i*2+1];
        whole_byte = strtol(byte_chars, NULL, 16);
        [out appendBytes:&whole_byte length:1];
    }
    return out;
}

- (void)testAnalyticsHeaders {
    [self setDeviceToken:self.validAPNSDeviceToken];

    NSDictionary *headers = self.analyticHeadersBlock();
    id expected = @{
        @"X-UA-Push-Address": validDeviceToken,
        @"X-UA-Channel-Opted-In": @"false",
        @"X-UA-Channel-Background-Enabled": @"false",
        @"X-UA-Notification-Prompted":@"false"
    };

    XCTAssertEqualObjects(expected, headers);
}

- (void)testAnalyticsHeadersPushDisabled {
    [self setDeviceToken:self.validAPNSDeviceToken];

    [self.privacyManager disableFeatures:UAFeaturesPush];

    NSDictionary *headers = self.analyticHeadersBlock();
    id expected = @{
        @"X-UA-Channel-Opted-In": @"false",
        @"X-UA-Channel-Background-Enabled": @"false"
    };

    XCTAssertEqualObjects(expected, headers);
}

- (void)testChannelExtensionWaitsForDeviceToken {
    [[[self.mockApplication stub] andReturnValue:@(YES)] isRegisteredForRemoteNotifications];

    UAChannelRegistrationPayload *payload = [[UAChannelRegistrationPayload alloc] init];
    XCTestExpectation *extendedPayload = [self expectationWithDescription:@"extended payload"];
    [self.testChannel extendPayload:payload completionHandler:^(UAChannelRegistrationPayload *payload) {
        [extendedPayload fulfill];
    }];

    [UADispatcher.main dispatchAsync:^{
        [self setDeviceToken:self.validAPNSDeviceToken];
    }];

    [self waitForTestExpectations];

    XCTAssertEqualObjects(validDeviceToken, payload.channel.pushAddress);
}

- (void)expectUpdatePushRegistrationWithOptions:(UANotificationOptions)expectedOptions categories:(NSSet<UNNotificationCategory *> *)expectedCategories {
    [[[[self.mockPushRegistration expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        UANotificationOptions options = (UANotificationOptions)arg;
        XCTAssertTrue(expectedOptions == options);

        [invocation getArgument:&arg atIndex:4];
        void (^completionHandler)(BOOL) = (__bridge void(^)(BOOL))arg;

        if (completionHandler) {
            completionHandler(YES);
        }

        [self.mockRegistrationDelegate notificationRegistrationFinishedWithAuthorizedSettings:self.authorizedNotificationSettings categories:expectedCategories status:UAAuthorizationStatusAuthorized];
    }] ignoringNonObjectArgs] updateRegistrationWithOptions:0 categories:[OCMArg checkWithBlock:^BOOL(NSSet<UNNotificationCategory *> *categories) {
        return (expectedCategories.count == categories.count);
    }] completionHandler:OCMOCK_ANY];
}

- (void)rejectUpdatePushRegistrationWithOptions {
    [[[self.mockPushRegistration reject] ignoringNonObjectArgs] updateRegistrationWithOptions:0 categories:OCMOCK_ANY completionHandler:OCMOCK_ANY];
}

@end


