/* Copyright Airship and Contributors */

#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>

#import "UAAccengage+Internal.h"
#import "UAChannel+Internal.h"
#import "UAPush+Internal.h"
#import "UAAnalytics+Internal.h"
#import "UAActionRunner.h"
#import "UAAccengagePayload.h"
#import "UAAccengageUtils.h"
#import "UARuntimeConfig+Internal.h"
#import "UALocaleManager+Internal.h"
#import "UARemoteConfigURLManager.h"
#import "UAPrivacyManager+Internal.h"
#import "UAirship+Internal.h"

@interface AirshipAccengageTests : XCTestCase

@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (nonatomic, strong) UARuntimeConfig *config;
@property (nonatomic, strong) UALocaleManager *localeManager;
@property (nonatomic, strong) UAPrivacyManager *privacyManager;
@property (nonatomic, strong) id mockChannel;
@property (nonatomic, strong) id mockPush;
@property (nonatomic, strong) id mockUserNotificationCenter;

@end

@implementation AirshipAccengageTests

- (void)setUp {
    self.dataStore = [UAPreferenceDataStore preferenceDataStoreWithKeyPrefix:NSUUID.UUID.UUIDString];
    self.privacyManager = [UAPrivacyManager privacyManagerWithDataStore:self.dataStore defaultEnabledFeatures:UAFeaturesNone];

    UARemoteConfigURLManager *urlManager = [UARemoteConfigURLManager remoteConfigURLManagerWithDataStore:self.dataStore];
    self.config = [[UARuntimeConfig alloc] initWithConfig:[UAConfig defaultConfig] urlManager:urlManager];
    self.localeManager = [UALocaleManager localeManagerWithDataStore:self.dataStore];

    self.mockChannel = OCMClassMock([UAChannel class]);
    self.mockPush = OCMClassMock([UAPush class]);

    self.mockUserNotificationCenter = OCMClassMock([UNUserNotificationCenter class]);
    [[[self.mockUserNotificationCenter stub] andReturn:self.mockUserNotificationCenter] currentNotificationCenter];
}

- (void)tearDown {
    [self.mockUserNotificationCenter stopMocking];
    [super tearDown];
}

- (UAAccengage *)createAccengageWithSettings:(NSDictionary *)settings {
    return [UAAccengage accengageWithDataStore:self.dataStore
                                       channel:self.mockChannel
                                          push:self.mockPush
                                privacyManager:self.privacyManager
                                      settings:settings];
}

- (void)testReceivedNotificationResponse {
    UAAccengage *accengage = [self createAccengageWithSettings:@{}];
    UAActionRunner *runner = [[UAActionRunner alloc] init];
    id runnerMock = [OCMockObject partialMockForObject:runner];
    
    NSDictionary *notificationInfo = @{
        @"aps": @{
                @"alert": @"test",
                @"category": @"test_category"
        },
        @"a4sid": @"7675",
        @"a4surl": @"someurl.com",
        @"a4sb": @[@{
                       @"action": @"webView",
                       @"bid": @"1",
                       @"url": @"someotherurl.com",
        },
                   @{
                       @"action": @"browser",
                       @"bid": @"2",
                       @"url": @"someotherurl.com",
        }]
    };

    UAAccengagePayload *payload = [UAAccengagePayload payloadWithDictionary:notificationInfo];
    XCTAssertEqual(payload.identifier, @"7675", @"Incorrect Accengage identifier");
    XCTAssertEqual(payload.url, @"someurl.com", @"Incorrect Accengage url");
    
    UAAccengageButton *button = [payload.buttons firstObject];
    XCTAssertEqual(button.actionType, @"webView", @"Incorrect Accengage button action type");
    XCTAssertEqual(button.identifier, @"1", @"Incorrect Accengage button identifier");
    XCTAssertEqual(button.url, @"someotherurl.com", @"Incorrect Accengage button url");
    
    UANotificationResponse *response = [UANotificationResponse notificationResponseWithNotificationInfo:notificationInfo actionIdentifier:UANotificationDefaultActionIdentifier responseText:nil];
    [[runnerMock expect] runActionWithName:@"landing_page_action" value:@"someurl.com"     situation:UASituationLaunchedFromPush];
    [accengage receivedNotificationResponse:response completionHandler:^{}];
    [runnerMock verify];
    
    response = [UANotificationResponse notificationResponseWithNotificationInfo:notificationInfo actionIdentifier:@"1" responseText:nil];
    [[runnerMock expect] runActionWithName:@"landing_page_action" value:@"someotherurl.com"     situation:UASituationForegroundInteractiveButton];
    [accengage receivedNotificationResponse:response completionHandler:^{}];
    [runnerMock verify];
    
    response = [UANotificationResponse notificationResponseWithNotificationInfo:notificationInfo actionIdentifier:@"2" responseText:nil];

    [[runnerMock expect] runActionWithName:@"open_external_url_action" value:@"someotherurl.com"     situation:UASituationForegroundInteractiveButton];
    [accengage receivedNotificationResponse:response completionHandler:^{}];
    [runnerMock verify];
    
    notificationInfo = @{
        @"aps": @{
                @"alert": @"test",
                @"category": @"test_category"
        },
        @"a4sid": @"7675",
        @"a4surl": @"someurl.com",
        @"openWithSafari": @"yes",
    };
    response = [UANotificationResponse notificationResponseWithNotificationInfo:notificationInfo actionIdentifier:UANotificationDefaultActionIdentifier responseText:nil];
    [[runnerMock expect] runActionWithName:@"open_external_url_action" value:@"someurl.com"     situation:UASituationLaunchedFromPush];
    [accengage receivedNotificationResponse:response completionHandler:^{}];
    [runnerMock verify];
}


- (void)testExtendChannel {
    __block UAChannelRegistrationExtenderBlock channelRegistrationExtenderBlock;

    // Capture the channel payload extender
    [[[self.mockChannel stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        channelRegistrationExtenderBlock =  (__bridge UAChannelRegistrationExtenderBlock)arg;
    }] addChannelExtenderBlock:OCMOCK_ANY];

    NSString *testDeviceID = @"123456";
    [self createAccengageWithSettings:@{@"BMA4SID":testDeviceID}];

    UAChannelRegistrationPayload *payload = [[UAChannelRegistrationPayload alloc] init];

    XCTestExpectation *channelCallback = [self expectationWithDescription:@"channel callback"];
    channelRegistrationExtenderBlock(payload, ^(UAChannelRegistrationPayload *payload) {
        XCTAssertEqual(testDeviceID, payload.accengageDeviceID);
        [channelCallback fulfill];
    });

    [self waitForExpectations:@[channelCallback] timeout:10];
}

- (void)testMigrateAnalyticsDoNotTrackNo {
    [self createAccengageWithSettings:@{@"BMA4SID": @"some-id", @"DoNotTrack": @YES}];
    XCTAssertFalse([self.privacyManager isEnabled:UAFeaturesAnalytics]);
}

- (void)testMigrateAnalyticsDoNotTrackYes {
    [self createAccengageWithSettings:@{@"BMA4SID": @"some-id", @"DoNotTrack": @NO}];
    XCTAssertTrue([self.privacyManager isEnabled:UAFeaturesAnalytics]);
}


- (void)testPresentationOptionsforNotification {
    UAAccengage *accengage = [self createAccengageWithSettings:@{}];

    id mockNotification = OCMClassMock([UNNotification class]);
    id mockRequest = OCMClassMock([UNNotificationRequest class]);
    id mockContent = OCMClassMock([UNNotificationContent class]);

    NSDictionary *notificationInfo = @{
        @"aps": @{
                @"alert": @"test",
                @"category": @"test_category"
        },
        @"a4sid": @"7675",
        @"a4surl": @"someurl.com",
        @"a4sb": @[@{
                       @"action": @"webView",
                       @"bid": @"1",
                       @"url": @"someotherurl.com",
        },
                   @{
                       @"action": @"browser",
                       @"bid": @"2",
                       @"url": @"someotherurl.com",
        }]
    };

    [[[mockNotification stub] andReturn:mockRequest] request];
    [[[mockRequest stub] andReturn:mockContent] content];
    [[[mockContent stub] andReturn:notificationInfo] userInfo];

    UNNotificationPresentationOptions defaultOptions = UNNotificationPresentationOptionAlert;

    if (@available(iOS 14.0, *)) {
        defaultOptions = UNNotificationPresentationOptionList | UNNotificationPresentationOptionBanner;
    }

    UNNotificationPresentationOptions options = [accengage presentationOptionsForNotification:mockNotification defaultPresentationOptions:defaultOptions];

    XCTAssertEqual(options, UNNotificationPresentationOptionNone, @"Incorrect notification presentation options");

    notificationInfo = @{
        @"aps": @{
                @"alert": @"test",
                @"category": @"test_category"
        },
        @"a4sid": @"7675",
        @"a4sd": @1,
        @"a4surl": @"someurl.com",
        @"a4sb": @[@{
                       @"action": @"webView",
                       @"bid": @"1",
                       @"url": @"someotherurl.com",
        },
                   @{
                       @"action": @"browser",
                       @"bid": @"2",
                       @"url": @"someotherurl.com",
        }]
    };

    [mockContent stopMocking];
    [mockNotification stopMocking];
    [mockRequest stopMocking];

    mockNotification = OCMClassMock([UNNotification class]);
    mockRequest = OCMClassMock([UNNotificationRequest class]);
    mockContent = OCMClassMock([UNNotificationContent class]);
    [[[mockNotification stub] andReturn:mockRequest] request];
    [[[mockRequest stub] andReturn:mockContent] content];
    [[[mockContent stub] andReturn:notificationInfo] userInfo];

    options = [accengage presentationOptionsForNotification:mockNotification defaultPresentationOptions:defaultOptions];

    XCTAssertEqual(options, [UAPush shared].defaultPresentationOptions, @"Incorrect notification presentation options");

    notificationInfo = @{
        @"aps": @{
                @"alert": @"test",
                @"category": @"test_category"
        },
        @"a4surl": @"someurl.com",
        @"a4sb": @[@{
                       @"action": @"webView",
                       @"bid": @"1",
                       @"url": @"someotherurl.com",
        },
                   @{
                       @"action": @"browser",
                       @"bid": @"2",
                       @"url": @"someotherurl.com",
        }]
    };

    [mockContent stopMocking];
    [mockNotification stopMocking];
    [mockRequest stopMocking];

    mockNotification = OCMClassMock([UNNotification class]);
    mockRequest = OCMClassMock([UNNotificationRequest class]);
    mockContent = OCMClassMock([UNNotificationContent class]);
    [[[mockNotification stub] andReturn:mockRequest] request];
    [[[mockRequest stub] andReturn:mockContent] content];
    [[[mockContent stub] andReturn:notificationInfo] userInfo];

    options = [accengage presentationOptionsForNotification:mockNotification defaultPresentationOptions:defaultOptions];

    XCTAssertEqual(options, defaultOptions, @"Incorrect notification presentation options");
}

- (void)testMigratePushEnabledSettings {
    id notificationSettingsMock = OCMClassMock([UNNotificationSettings class]);
    [[[notificationSettingsMock stub] andReturnValue:OCMOCK_VALUE(UNAuthorizationStatusAuthorized)] authorizationStatus];

    typedef void (^NotificationSettingsReturnBlock)(UNNotificationSettings * _Nonnull settings);

    [[[self.mockUserNotificationCenter stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        NotificationSettingsReturnBlock returnBlock = (__bridge NotificationSettingsReturnBlock)arg;
        returnBlock(notificationSettingsMock);
    }] getNotificationSettingsWithCompletionHandler:OCMOCK_ANY];

    [[self.mockPush expect] setUserPushNotificationsEnabled:YES];

    [self createAccengageWithSettings:@{@"BMA4SID": @"some-id", @"DoNotTrack": @NO}];

    [self.mockPush verify];
    XCTAssertTrue([self.privacyManager isEnabled:UAFeaturesPush]);
}

- (void)testMigratePushDisabledSettings {
    id notificationSettingsMock = OCMClassMock([UNNotificationSettings class]);
    [[[notificationSettingsMock stub] andReturnValue:OCMOCK_VALUE(UNAuthorizationStatusDenied)] authorizationStatus];

    typedef void (^NotificationSettingsReturnBlock)(UNNotificationSettings * _Nonnull settings);

    [[[self.mockUserNotificationCenter stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        NotificationSettingsReturnBlock returnBlock = (__bridge NotificationSettingsReturnBlock)arg;
        returnBlock(notificationSettingsMock);
    }] getNotificationSettingsWithCompletionHandler:OCMOCK_ANY];

    [[self.mockPush reject] setUserPushNotificationsEnabled:NO];
    [[self.mockPush reject] setUserPushNotificationsEnabled:YES];
    [self createAccengageWithSettings:@{@"BMA4SID": @"some-id", @"DoNotTrack": @NO}];

    [self.mockPush verify];
    XCTAssertFalse([self.privacyManager isEnabled:UAFeaturesPush]);
}

@end
