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

@interface AirshipAccengageTests : XCTestCase

@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (nonatomic, strong) UARuntimeConfig *config;
@property (nonatomic, strong) UAChannel *channel;
@property (nonatomic, strong) UAAnalytics *analytics;
@property (nonatomic, strong) id mockPush;

@end

@interface UAAccengage()

- (void)extendChannelRegistrationPayload:(UAChannelRegistrationPayload *)payload completionHandler:(UAChannelRegistrationExtenderCompletionHandler)completionHandler;
- (instancetype)init;
- (void)migrateSettingsToAnalytics:(UAAnalytics *)analytics;
- (void)migratePushSettings:(UAPush *)push completionHandler:(void (^)(void))completionHandler;
- (instancetype)initWithDataStore:(UAPreferenceDataStore *)dataStore
                          channel:(UAChannel<UAExtendableChannelRegistration> *)channel
                             push:(UAPush *)push
                        analytics:(UAAnalytics *)analytics;
@property (nonatomic, strong) NSDictionary *accengageSettings;

@end

@implementation AirshipAccengageTests

- (void)setUp {
    self.dataStore = [UAPreferenceDataStore preferenceDataStoreWithKeyPrefix:@"test"];
    self.config = [[UARuntimeConfig alloc] initWithConfig:[UAConfig defaultConfig]];
    UATagGroupsMutationHistory *history = [[UATagGroupsMutationHistory alloc] init];
    UATagGroupsRegistrar *tagGroupsRegistar = [UATagGroupsRegistrar tagGroupsRegistrarWithConfig:self.config dataStore:self.dataStore mutationHistory:history];
    self.channel = [UAChannel channelWithDataStore:self.dataStore config:self.config tagGroupsRegistrar:tagGroupsRegistar];
    self.analytics = [UAAnalytics analyticsWithConfig:self.config dataStore:self.dataStore channel:self.channel];
    id registration = OCMClassMock([UAAPNSRegistration class]);
    UAPush *push = [UAPush pushWithConfig:self.config dataStore:self.dataStore channel:self.channel analytics:self.analytics appStateTracker:[UAAppStateTracker shared] notificationCenter:[NSNotificationCenter defaultCenter] pushRegistration:registration application:[UIApplication sharedApplication] dispatcher:[UADispatcher mainDispatcher]];
    self.mockPush = OCMPartialMock(push);
}

- (void)testReceivedNotificationResponse {
    UAAccengage *accengage = [[UAAccengage alloc] init];
    
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

- (void)testInitWithDataStore {
    UATagGroupsMutationHistory *history = [[UATagGroupsMutationHistory alloc] init];
    UATagGroupsRegistrar *tagGroupsRegistar = [UATagGroupsRegistrar tagGroupsRegistrarWithConfig:self.config dataStore:self.dataStore mutationHistory:history];
    UAChannel *channel = [UAChannel channelWithDataStore:self.dataStore config:self.config tagGroupsRegistrar:tagGroupsRegistar];
    id channelMock = OCMPartialMock(channel);
    [[channelMock expect] addChannelExtenderBlock:OCMOCK_ANY];
    
    id pushMock = OCMClassMock([UAPush class]);
    id userNotificationCenterMock = OCMClassMock([UNUserNotificationCenter class]);
    [[[userNotificationCenterMock stub] andReturn:userNotificationCenterMock] currentNotificationCenter];
    
    UAAccengage *accengage = [[UAAccengage alloc] initWithDataStore:self.dataStore channel:channelMock push:pushMock analytics:self.analytics];
    
    [channelMock verify];
}

- (void)testExtendChannel {
    UAAccengage *accengage = [[UAAccengage alloc] init];
    
    id archiverMock = OCMClassMock([NSKeyedUnarchiver class]);
    id utilsMock = OCMClassMock([UAAccengageUtils class]);
    
    NSString *testDeviceID = @"123456";
    NSDictionary *testDictionary = @{@"BMA4SID":testDeviceID};
    
    NSData *data = [testDeviceID dataUsingEncoding:NSUTF8StringEncoding];
    
    [[[archiverMock stub] andReturn:data] unarchiveObjectWithFile:OCMOCK_ANY];
    [[[archiverMock stub] andReturn:testDictionary] unarchiveObjectWithData:OCMOCK_ANY];
    [[[utilsMock stub] andReturn:data] decryptData:OCMOCK_ANY key:OCMOCK_ANY];

    UAChannelRegistrationPayload *payload = [[UAChannelRegistrationPayload alloc] init];
    id payloadMock = OCMPartialMock(payload);

    NSString *accengageDeviceID = UIDevice.currentDevice.identifierForVendor.UUIDString;
    
    [[payloadMock expect] setAccengageDeviceID:testDeviceID];
    
    UAChannelRegistrationExtenderCompletionHandler handler = ^(UAChannelRegistrationPayload *payload) {};
       
    [accengage extendChannelRegistrationPayload:payloadMock completionHandler:handler];
    
    [payloadMock verify];
    
    [archiverMock stopMocking];
    [utilsMock stopMocking];
    accengage.accengageSettings = nil;
    
    archiverMock = OCMClassMock([NSKeyedUnarchiver class]);
    utilsMock = OCMClassMock([UAAccengageUtils class]);
       
    [[[archiverMock stub] andReturn:data] unarchiveObjectWithFile:OCMOCK_ANY];
    [[[archiverMock stub] andReturn:@{}] unarchiveObjectWithData:OCMOCK_ANY];
    [[[utilsMock stub] andReturn:data] decryptData:OCMOCK_ANY key:OCMOCK_ANY];
    
    [[payloadMock expect] setAccengageDeviceID:accengageDeviceID];
    
    [accengage extendChannelRegistrationPayload:payloadMock completionHandler:handler];
    
    [payloadMock verify];
}

- (void)testMigrateSettings {
    id archiverMock = OCMClassMock([NSKeyedUnarchiver class]);
    id utilsMock = OCMClassMock([UAAccengageUtils class]);
    
    NSDictionary *testDictionary = @{@"DoNotTrack":@NO};
    
    NSString *testString = @"test";
    NSData *data = [testString dataUsingEncoding:NSUTF8StringEncoding];
    
    [[[archiverMock stub] andReturn:data] unarchiveObjectWithFile:OCMOCK_ANY];
    [[[archiverMock stub] andReturn:testDictionary] unarchiveObjectWithData:OCMOCK_ANY];
    [[[utilsMock stub] andReturn:data] decryptData:OCMOCK_ANY key:OCMOCK_ANY];
    
    UAAccengage *accengage = [[UAAccengage alloc] init];
    [accengage migrateSettingsToAnalytics:self.analytics];
     
    XCTAssertTrue(self.analytics.isEnabled);
    
    [archiverMock stopMocking];
    [utilsMock stopMocking];
    accengage.accengageSettings = nil;
    
    archiverMock = OCMClassMock([NSKeyedUnarchiver class]);
    utilsMock = OCMClassMock([UAAccengageUtils class]);
    
    testDictionary = @{@"DoNotTrack":@YES};
    [[[archiverMock stub] andReturn:data] unarchiveObjectWithFile:OCMOCK_ANY];
    [[[archiverMock stub] andReturn:testDictionary] unarchiveObjectWithData:OCMOCK_ANY];
    [[[utilsMock stub] andReturn:data] decryptData:OCMOCK_ANY key:OCMOCK_ANY];
    
    [accengage migrateSettingsToAnalytics:self.analytics];
        
    XCTAssertFalse(self.analytics.isEnabled);
}

- (void)testPresentationOptionsforNotification {
    UAAccengage *accengage = [[UAAccengage alloc] init];
    
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

- (void)testMigratePushSettings {
    id userNotificationCenterMock = OCMClassMock([UNUserNotificationCenter class]);
    [[[userNotificationCenterMock stub] andReturn:userNotificationCenterMock] currentNotificationCenter];
    id notificationSettingsMock = OCMClassMock([UNNotificationSettings class]);
    [[[notificationSettingsMock stub] andReturnValue:OCMOCK_VALUE(UNAuthorizationStatusAuthorized)] authorizationStatus];
    
    typedef void (^NotificationSettingsReturnBlock)(UNNotificationSettings * _Nonnull settings);

    [[[userNotificationCenterMock stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        NotificationSettingsReturnBlock returnBlock = (__bridge NotificationSettingsReturnBlock)arg;
        returnBlock(notificationSettingsMock);
    }] getNotificationSettingsWithCompletionHandler:OCMOCK_ANY];
        
    UAAccengage *accengage = [[UAAccengage alloc] init];
    [accengage migratePushSettings:self.mockPush completionHandler:^{}];
    
    BOOL notificationsEnabled = [self.mockPush userPushNotificationsEnabled];
 
    XCTAssertTrue(notificationsEnabled, @"User notification setting doesn't match the authorization status");
    [notificationSettingsMock verify];
        
    [userNotificationCenterMock stopMocking];
    [notificationSettingsMock stopMocking];
    
    userNotificationCenterMock = OCMClassMock([UNUserNotificationCenter class]);
    [[[userNotificationCenterMock stub] andReturn:userNotificationCenterMock] currentNotificationCenter];
    notificationSettingsMock = OCMClassMock([UNNotificationSettings class]);
    [[[notificationSettingsMock stub] andReturnValue:OCMOCK_VALUE(UNAuthorizationStatusDenied)] authorizationStatus];
    
    [[[userNotificationCenterMock stub] andDo:^(NSInvocation *invocation) {
           void *arg;
           [invocation getArgument:&arg atIndex:2];
           NotificationSettingsReturnBlock returnBlock = (__bridge NotificationSettingsReturnBlock)arg;
           returnBlock(notificationSettingsMock);
       }] getNotificationSettingsWithCompletionHandler:OCMOCK_ANY];
    
    [accengage migratePushSettings:self.mockPush completionHandler:^{}];
    
    notificationsEnabled = [self.mockPush userPushNotificationsEnabled];
    
    XCTAssertFalse(notificationsEnabled, @"User notification setting doesn't match the authorization status");
    [notificationSettingsMock verify];
}

@end
