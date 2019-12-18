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

@property (nonatomic, strong) UAAnalytics *analytics;

@end

@interface UAAccengage()

- (void)extendChannelRegistrationPayload:(UAChannelRegistrationPayload *)payload completionHandler:(UAChannelRegistrationExtenderCompletionHandler)completionHandler;
- (instancetype)init;
- (void)migrateSettingsToAnalytics:(UAAnalytics *)analytics;

@end

@implementation AirshipAccengageTests

- (UAAccengage *)setUpAccengage {
    UAPreferenceDataStore *dataStore = [UAPreferenceDataStore preferenceDataStoreWithKeyPrefix:@"test"];
    UARuntimeConfig *config = [[UARuntimeConfig alloc] initWithConfig:[UAConfig defaultConfig]];
    UATagGroupsMutationHistory *history = [[UATagGroupsMutationHistory alloc] init];
    UATagGroupsRegistrar *tagGroupsRegistar = [UATagGroupsRegistrar tagGroupsRegistrarWithConfig:config dataStore:dataStore mutationHistory:history];
    UAChannel *channel = [UAChannel channelWithDataStore:dataStore config:config tagGroupsRegistrar:tagGroupsRegistar];
    self.analytics = [UAAnalytics analyticsWithConfig:config dataStore:dataStore channel:channel];
    id push = OCMClassMock([UAPush class]);

    UAAccengage<UAPushableComponent> *accengage = [UAAccengage accengageWithDataStore:dataStore channel:channel push:push analytics:self.analytics];
    return accengage;
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
        @"openWithSafari": @true,
    };
    response = [UANotificationResponse notificationResponseWithNotificationInfo:notificationInfo actionIdentifier:UANotificationDefaultActionIdentifier responseText:nil];
    [[runnerMock expect] runActionWithName:@"open_external_url_action" value:@"someurl.com"     situation:UASituationLaunchedFromPush];
    [accengage receivedNotificationResponse:response completionHandler:^{}];
    [runnerMock verify];
}

- (void)testInitWithDataStore {
    UAPreferenceDataStore *dataStore = [[UAPreferenceDataStore alloc] init];
    UARuntimeConfig *config = [[UARuntimeConfig alloc] init];
    UATagGroupsMutationHistory *history = [[UATagGroupsMutationHistory alloc] init];
    UATagGroupsRegistrar *tagGroupsRegistar = [UATagGroupsRegistrar tagGroupsRegistrarWithConfig:config dataStore:dataStore mutationHistory:history];
    UAChannel *channel = [UAChannel channelWithDataStore:dataStore config:config tagGroupsRegistrar:tagGroupsRegistar];
    id channelMock = OCMPartialMock(channel);
    UAAnalytics *analytics = [UAAnalytics analyticsWithConfig:config dataStore:dataStore channel:channelMock];
    id push = OCMClassMock([UAPush class]);
    
    [[channelMock expect] addChannelExtenderBlock:OCMOCK_ANY];
    
    UAAccengage *accengage = [UAAccengage accengageWithDataStore:dataStore channel:channelMock push:push analytics:analytics];
    
    [channelMock verify];
  
}

- (void)testExtendChannel {
    UAAccengage *accengage = [[UAAccengage alloc] init];
    
    UAChannelRegistrationPayload *payload = [[UAChannelRegistrationPayload alloc] init];
    id payloadMock = OCMPartialMock(payload);

    NSString *accengageDeviceID = UIDevice.currentDevice.identifierForVendor.UUIDString;
    
    [[payloadMock expect] setAccengageDeviceID:accengageDeviceID];
    
    UAChannelRegistrationExtenderCompletionHandler handler = ^(UAChannelRegistrationPayload *payload) {};
       
    [accengage extendChannelRegistrationPayload:payloadMock completionHandler:handler];
    
    [payloadMock verify];
}

- (void)testMigrateSettings {
    id mockArchiver = OCMClassMock([NSKeyedUnarchiver class]);
    id mockUtils = OCMClassMock([UAAccengageUtils class]);
    
    NSDictionary *testDictionary = @{@"DoNotTrack":@NO};
    
    NSString *testString = @"test";
    NSData *data = [testString dataUsingEncoding:NSUTF8StringEncoding];
    
    [[[mockArchiver stub] andReturn:data] unarchiveObjectWithFile:OCMOCK_ANY];
    [[[mockArchiver stub] andReturn:testDictionary] unarchiveObjectWithData:OCMOCK_ANY];
    [[[mockUtils stub] andReturn:data] decryptData:OCMOCK_ANY key:OCMOCK_ANY];
    
    UAAccengage *accengage = [self setUpAccengage];
     
    XCTAssertTrue(self.analytics.isEnabled);
    
    [mockArchiver stopMocking];
    [mockUtils stopMocking];
    
    mockArchiver = OCMClassMock([NSKeyedUnarchiver class]);
    mockUtils = OCMClassMock([UAAccengageUtils class]);
    
    testDictionary = @{@"DoNotTrack":@YES};
    [[[mockArchiver stub] andReturn:data] unarchiveObjectWithFile:OCMOCK_ANY];
    [[[mockArchiver stub] andReturn:testDictionary] unarchiveObjectWithData:OCMOCK_ANY];
    [[[mockUtils stub] andReturn:data] decryptData:OCMOCK_ANY key:OCMOCK_ANY];[accengage migrateSettingsToAnalytics:self.analytics];
        
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

@end
