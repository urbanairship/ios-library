/* Copyright Airship and Contributors */

#import "UABaseTest.h"

#import "AirshipTests-Swift.h"

@interface UAAPNSRegistrationTest : UABaseTest

@property (nonatomic, strong) id mockedApplication;
@property (nonatomic, strong) id mockedUserNotificationCenter;

@property (nonatomic, strong) UAAPNSRegistration *pushRegistration;
@property (nonatomic, copy) NSSet<UNNotificationCategory *> *testCategories;

@end

@implementation UAAPNSRegistrationTest

- (void)setUp {
    [super setUp];

    self.mockedUserNotificationCenter = [self mockForClass:[UNUserNotificationCenter class]];
    [[[self.mockedUserNotificationCenter stub] andReturn:self.mockedUserNotificationCenter] currentNotificationCenter];

    // Set up a mocked application
    self.mockedApplication = [self mockForClass:[UIApplication class]];
    [[[self.mockedApplication stub] andReturn:self.mockedApplication] sharedApplication];

    // Create APNS registration object
    self.pushRegistration = [[UAAPNSRegistration alloc] init];

    //Set ip some categories to use
    UNNotificationCategory *defaultCategory = [UNNotificationCategory categoryWithIdentifier:@"defaultCategory" actions:@[]  intentIdentifiers:@[] options:UNNotificationCategoryOptionNone];
    UNNotificationCategory *customCategory = [UNNotificationCategory categoryWithIdentifier:@"customCategory" actions:@[]  intentIdentifiers:@[] options:UNNotificationCategoryOptionNone];
    UNNotificationCategory *anotherCustomCategory = [UNNotificationCategory categoryWithIdentifier:@"anotherCustomCategory" actions:@[] intentIdentifiers:@[] hiddenPreviewsBodyPlaceholder:@"Push Notification" options:UNNotificationCategoryOptionNone];

    self.testCategories = [NSSet setWithArray:@[defaultCategory, customCategory, anotherCustomCategory]];
}

- (void)tearDown {
    [self.mockedUserNotificationCenter stopMocking];
    self.pushRegistration = nil;
    [super tearDown];
}

-(void)testUpdateRegistrationSetsCategories {

    UANotificationOptions expectedOptions = UANotificationOptionAlert & UANotificationOptionBadge;

    [[self.mockedUserNotificationCenter expect] setNotificationCategories:self.testCategories];

    [self.pushRegistration updateRegistrationWithOptions:expectedOptions categories:self.testCategories completionHandler:nil];

    [self.mockedUserNotificationCenter verify];
}

-(void)testUpdateRegistration {
    UANotificationOptions expectedOptions = UANotificationOptionAlert | UANotificationOptionBadge;

    // Normalize the options
    UNAuthorizationOptions normalizedOptions = (UNAuthorizationOptionAlert | UNAuthorizationOptionBadge | UNAuthorizationOptionSound | UNAuthorizationOptionCarPlay);
    normalizedOptions &= expectedOptions;

    [[self.mockedUserNotificationCenter expect] requestAuthorizationWithOptions:normalizedOptions completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(BOOL granted, NSError * _Nullable error) = obj;
        [[self.mockedApplication expect] registerForRemoteNotifications];
        completionBlock(YES, nil);
        return YES;
    }]];

    [self.pushRegistration updateRegistrationWithOptions:expectedOptions categories:self.testCategories completionHandler:nil];

    [self.mockedUserNotificationCenter verify];
}

-(void)testGetCurrentAuthorization {

    // These expected options must match mocked UNNotificationSettings object below for the test to be valid
    UAAuthorizedNotificationSettings expectedSettings =  UAAuthorizedNotificationSettingsAlert | UAAuthorizedNotificationSettingsBadge |
        UAAuthorizedNotificationSettingsSound | UAAuthorizedNotificationSettingsCarPlay;

    // Mock UNNotificationSettings object to match expected options since we can't initialize one
    id mockNotificationSettings = [self mockForClass:[UNNotificationSettings class]];
    [[[mockNotificationSettings stub] andReturnValue:OCMOCK_VALUE(UNAuthorizationStatusAuthorized)] authorizationStatus];
    [[[mockNotificationSettings stub] andReturnValue:OCMOCK_VALUE(UNNotificationSettingEnabled)] alertSetting];
    [[[mockNotificationSettings stub] andReturnValue:OCMOCK_VALUE(UNNotificationSettingEnabled)] soundSetting];
    [[[mockNotificationSettings stub] andReturnValue:OCMOCK_VALUE(UNNotificationSettingEnabled)] badgeSetting];
    [[[mockNotificationSettings stub] andReturnValue:OCMOCK_VALUE(UNNotificationSettingEnabled)] carPlaySetting];

    typedef void (^NotificationSettingsReturnBlock)(UNNotificationSettings * _Nonnull settings);

    [[[self.mockedUserNotificationCenter stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        NotificationSettingsReturnBlock returnBlock = (__bridge NotificationSettingsReturnBlock)arg;
        returnBlock(mockNotificationSettings);

    }] getNotificationSettingsWithCompletionHandler:OCMOCK_ANY];

    [self.pushRegistration getAuthorizedSettingsWithCompletionHandler:^(UAAuthorizedNotificationSettings authorizedSettings, UAAuthorizationStatus status) {
        XCTAssertTrue(authorizedSettings == expectedSettings);
        XCTAssertFalse(status == UAAuthorizationStatusProvisional);
    }];
}

-(void)testGetCurrentAuthorizationProvisional {
    // Provisional auth is only on iOS 12 and above
    if (@available(iOS 12.0, *)) {
        // These expected options must match mocked UNNotificationSettings object below for the test to be valid
        UAAuthorizedNotificationSettings expectedSettings =  UAAuthorizedNotificationSettingsLockScreen |
                                                             UAAuthorizedNotificationSettingsNotificationCenter;

        // Mock UNNotificationSettings object to match expected options since we can't initialize one
        id mockNotificationSettings = [self mockForClass:[UNNotificationSettings class]];
        [[[mockNotificationSettings stub] andReturnValue:OCMOCK_VALUE(UNAuthorizationStatusProvisional)] authorizationStatus];
        [[[mockNotificationSettings stub] andReturnValue:OCMOCK_VALUE(UNNotificationSettingEnabled)] lockScreenSetting];
        [[[mockNotificationSettings stub] andReturnValue:OCMOCK_VALUE(UNNotificationSettingEnabled)] notificationCenterSetting];

        typedef void (^NotificationSettingsReturnBlock)(UNNotificationSettings * _Nonnull settings);

        [[[self.mockedUserNotificationCenter stub] andDo:^(NSInvocation *invocation) {
            void *arg;
            [invocation getArgument:&arg atIndex:2];
            NotificationSettingsReturnBlock returnBlock = (__bridge NotificationSettingsReturnBlock)arg;
            returnBlock(mockNotificationSettings);

        }] getNotificationSettingsWithCompletionHandler:OCMOCK_ANY];

        [self.pushRegistration getAuthorizedSettingsWithCompletionHandler:^(UAAuthorizedNotificationSettings authorizedSettings, UAAuthorizationStatus status) {
            XCTAssertTrue(authorizedSettings == expectedSettings);
            XCTAssertTrue(status == UAAuthorizationStatusProvisional);
        }];
    }
}

-(void)testGetCriticalAlertAuthorization {
    // Critical alerts are only on iOS 12 and above
    if (@available(iOS 12.0, *)) {
        // These expected options must match mocked UNNotificationSettings object below for the test to be valid
        UAAuthorizedNotificationSettings expectedSettings =  UAAuthorizedNotificationSettingsCriticalAlert;

        // Mock UNNotificationSettings object to match expected options since we can't initialize one
        id mockNotificationSettings = [self mockForClass:[UNNotificationSettings class]];
        [[[mockNotificationSettings stub] andReturnValue:OCMOCK_VALUE(UNAuthorizationStatusAuthorized)] authorizationStatus];
        [[[mockNotificationSettings stub] andReturnValue:OCMOCK_VALUE(UNNotificationSettingEnabled)] criticalAlertSetting];

        typedef void (^NotificationSettingsReturnBlock)(UNNotificationSettings * _Nonnull settings);

        [[[self.mockedUserNotificationCenter stub] andDo:^(NSInvocation *invocation) {
            void *arg;
            [invocation getArgument:&arg atIndex:2];
            NotificationSettingsReturnBlock returnBlock = (__bridge NotificationSettingsReturnBlock)arg;
            returnBlock(mockNotificationSettings);

        }] getNotificationSettingsWithCompletionHandler:OCMOCK_ANY];

        [self.pushRegistration getAuthorizedSettingsWithCompletionHandler:^(UAAuthorizedNotificationSettings authorizedSettings, UAAuthorizationStatus status) {
            XCTAssertTrue(authorizedSettings == expectedSettings);
            XCTAssertTrue(status == UAAuthorizationStatusAuthorized);
        }];
    }
}

-(void)testGetAnnouncementAuthorization {
    // Announcement setting is only on iOS 13 and above
    if (@available(iOS 13.0, *)) {
        // These expected options must match mocked UNNotificationSettings object below for the test to be valid
        UAAuthorizedNotificationSettings expectedSettings =  UAAuthorizedNotificationSettingsAnnouncement;

        // Mock UNNotificationSettings object to match expected options since we can't initialize one
        id mockNotificationSettings = [self mockForClass:[UNNotificationSettings class]];
        [[[mockNotificationSettings stub] andReturnValue:OCMOCK_VALUE(UNAuthorizationStatusAuthorized)] authorizationStatus];
        [[[mockNotificationSettings stub] andReturnValue:OCMOCK_VALUE(UNNotificationSettingEnabled)] announcementSetting];

        typedef void (^NotificationSettingsReturnBlock)(UNNotificationSettings * _Nonnull settings);

        [[[self.mockedUserNotificationCenter stub] andDo:^(NSInvocation *invocation) {
            void *arg;
            [invocation getArgument:&arg atIndex:2];
            NotificationSettingsReturnBlock returnBlock = (__bridge NotificationSettingsReturnBlock)arg;
            returnBlock(mockNotificationSettings);

        }] getNotificationSettingsWithCompletionHandler:OCMOCK_ANY];

        [self.pushRegistration getAuthorizedSettingsWithCompletionHandler:^(UAAuthorizedNotificationSettings authorizedSettings, UAAuthorizationStatus status) {
            XCTAssertTrue(authorizedSettings == expectedSettings);
            XCTAssertTrue(status == UAAuthorizationStatusAuthorized);
        }];
    }
}

-(void)testGetTimeSensitiveAuthorization {
    // Announcement setting is only on iOS 13 and above
    if (@available(iOS 15.0, *)) {
        // These expected options must match mocked UNNotificationSettings object below for the test to be valid
        UAAuthorizedNotificationSettings expectedSettings =  UAAuthorizedNotificationSettingsTimeSensitive;

        // Mock UNNotificationSettings object to match expected options since we can't initialize one
        id mockNotificationSettings = [self mockForClass:[UNNotificationSettings class]];
        [[[mockNotificationSettings stub] andReturnValue:OCMOCK_VALUE(UNAuthorizationStatusAuthorized)] authorizationStatus];
        [[[mockNotificationSettings stub] andReturnValue:OCMOCK_VALUE(UNNotificationSettingEnabled)] timeSensitiveSetting];

        typedef void (^NotificationSettingsReturnBlock)(UNNotificationSettings * _Nonnull settings);

        [[[self.mockedUserNotificationCenter stub] andDo:^(NSInvocation *invocation) {
            void *arg;
            [invocation getArgument:&arg atIndex:2];
            NotificationSettingsReturnBlock returnBlock = (__bridge NotificationSettingsReturnBlock)arg;
            returnBlock(mockNotificationSettings);

        }] getNotificationSettingsWithCompletionHandler:OCMOCK_ANY];

        [self.pushRegistration getAuthorizedSettingsWithCompletionHandler:^(UAAuthorizedNotificationSettings authorizedSettings, UAAuthorizationStatus status) {
            XCTAssertTrue(authorizedSettings == expectedSettings);
            XCTAssertTrue(status == UAAuthorizationStatusAuthorized);
        }];
    }
}

-(void)testGetScheduledDeliveryAuthorization {
    // Announcement setting is only on iOS 13 and above
    if (@available(iOS 15.0, *)) {
        // These expected options must match mocked UNNotificationSettings object below for the test to be valid
        UAAuthorizedNotificationSettings expectedSettings =  UAAuthorizedNotificationSettingsScheduledDelivery;

        // Mock UNNotificationSettings object to match expected options since we can't initialize one
        id mockNotificationSettings = [self mockForClass:[UNNotificationSettings class]];
        [[[mockNotificationSettings stub] andReturnValue:OCMOCK_VALUE(UNAuthorizationStatusAuthorized)] authorizationStatus];
        [[[mockNotificationSettings stub] andReturnValue:OCMOCK_VALUE(UNNotificationSettingEnabled)] scheduledDeliverySetting];

        typedef void (^NotificationSettingsReturnBlock)(UNNotificationSettings * _Nonnull settings);

        [[[self.mockedUserNotificationCenter stub] andDo:^(NSInvocation *invocation) {
            void *arg;
            [invocation getArgument:&arg atIndex:2];
            NotificationSettingsReturnBlock returnBlock = (__bridge NotificationSettingsReturnBlock)arg;
            returnBlock(mockNotificationSettings);

        }] getNotificationSettingsWithCompletionHandler:OCMOCK_ANY];

        [self.pushRegistration getAuthorizedSettingsWithCompletionHandler:^(UAAuthorizedNotificationSettings authorizedSettings, UAAuthorizationStatus status) {
            XCTAssertTrue(authorizedSettings == expectedSettings);
            XCTAssertTrue(status == UAAuthorizationStatusAuthorized);
        }];
    }
}

@end

