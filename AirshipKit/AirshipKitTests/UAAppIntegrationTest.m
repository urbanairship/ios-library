/* Copyright 2018 Urban Airship and Contributors */

#import "UABaseTest.h"

#import "UAAppIntegration+Internal.h"
#import "UANotificationAction.h"
#import "UANotificationCategory.h"
#import "UAPush+Internal.h"
#import "UAAnalytics+Internal.h"
#import "UAInteractiveNotificationEvent+Internal.h"
#import "UAPushReceivedEvent+Internal.h"
#import "UAActionRunner+Internal.h"
#import "UAActionRegistry+Internal.h"
#import "UADeviceRegistrationEvent+Internal.h"
#import "UAConfig.h"
#import "UANotificationContent.h"
#import "UAirship+Internal.h"

#if !TARGET_OS_TV
#import "UAInbox+Internal.h"
#import "UAInboxMessageList.h"
#import "UAInboxUtils.h"
#import "UADisplayInboxAction.h"
#endif

@interface UAAppIntegrationTest : UABaseTest
@property (nonatomic, strong) id mockedApplication;
@property (nonatomic, strong) id mockedUserNotificationCenter;
@property (nonatomic, strong) id mockedAirship;
@property (nonatomic, strong) id mockedAnalytics;
@property (nonatomic, strong) id mockedPush;
@property (nonatomic, strong) id mockedActionRunner;
@property (nonatomic, strong) id mockedProcessInfo;
@property (nonatomic, strong) id mockedInbox;
@property (nonatomic, strong) id mockedMessageList;

@property (nonatomic, strong) id mockedUNNotificationResponse;

@property (nonatomic, strong) id mockedUANotificationContent;
@property (nonatomic, strong) id mockedUNNotification;
@property (nonatomic, strong) id mockedUNNotificationRequest;
@property (nonatomic, strong) id mockedUNNotificationContent;

@property (nonatomic, assign) NSUInteger testOSMajorVersion;
@property (nonatomic, strong) NSDictionary *notification;

@end

@implementation UAAppIntegrationTest

- (void)setUp {
    [super setUp];

    self.testOSMajorVersion = 8;
    self.mockedProcessInfo = [self mockForClass:[NSProcessInfo class]];
    [[[self.mockedProcessInfo stub] andReturn:self.mockedProcessInfo] processInfo];

    [[[[self.mockedProcessInfo stub] andDo:^(NSInvocation *invocation) {
        NSOperatingSystemVersion arg;
        [invocation getArgument:&arg atIndex:2];

        BOOL result = self.testOSMajorVersion >= arg.majorVersion;
        [invocation setReturnValue:&result];
    }] ignoringNonObjectArgs] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){0, 0, 0}];

    // Set up a mocked application
    self.mockedApplication = [self mockForClass:[UIApplication class]];
    [[[self.mockedApplication stub] andReturn:self.mockedApplication] sharedApplication];

    // Set up mocked User Notification Center
    self.mockedUserNotificationCenter = [self mockForClass:[UNUserNotificationCenter class]];
    [[[self.mockedUserNotificationCenter stub] andReturn:self.mockedUserNotificationCenter] currentNotificationCenter];

    self.mockedActionRunner = [self mockForClass:[UAActionRunner class]];

    self.mockedAnalytics = [self mockForClass:[UAAnalytics class]];
    self.mockedPush = [self mockForClass:[UAPush class]];

    self.mockedInbox = [self mockForClass:[UAInbox class]];
    self.mockedMessageList = [self mockForClass:[UAInboxMessageList class]];
    [[[self.mockedInbox stub] andReturn:self.mockedMessageList] messageList];

    self.mockedAirship = [self mockForClass:[UAirship class]];
    [[[self.mockedAirship stub] andReturn:self.mockedAnalytics] sharedAnalytics];
    [[[self.mockedAirship stub] andReturn:self.mockedPush] push];
    [[[self.mockedAirship stub] andReturn:self.mockedInbox] inbox];

    [UAirship setSharedAirship:self.mockedAirship];


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
                          @"someActionKey": @"someActionValue"
                          };

    // Mock the nested apple types with unavailable init methods
    self.mockedUANotificationContent = [self mockForClass:[UANotificationContent class]];
    [[[self.mockedUANotificationContent stub] andReturn:self.mockedUANotificationContent] notificationWithUNNotification:OCMOCK_ANY];
    [[[self.mockedUANotificationContent stub] andReturn:self.notification] notificationInfo];

    self.mockedUNNotification = [self mockForClass:[UNNotification class]];
    self.mockedUNNotificationRequest = [self mockForClass:[UNNotificationRequest class]];
    self.mockedUNNotificationContent = [self mockForClass:[UNNotificationContent class]];

    [[[self.mockedUNNotification stub] andReturn:self.mockedUNNotificationRequest] request];
    [[[self.mockedUNNotificationRequest stub] andReturn:self.mockedUNNotificationContent] content];
    [[[self.mockedUNNotificationContent stub] andReturn:self.notification] userInfo];

    self.mockedUNNotificationResponse = [self mockForClass:[UNNotificationResponse class]];
    [[[self.mockedUNNotificationResponse stub] andReturn:self.mockedUNNotification] notification];
}

- (void)tearDown {
    [self.mockedApplication stopMocking];
    [self.mockedAnalytics stopMocking];
    [self.mockedAirship stopMocking];
    [self.mockedActionRunner stopMocking];
    [self.mockedPush stopMocking];
    [self.mockedProcessInfo stopMocking];
    [self.mockedUserNotificationCenter stopMocking];
    [self.mockedInbox stopMocking];
    [self.mockedMessageList stopMocking];

    [self.mockedUANotificationContent stopMocking];
    [self.mockedUNNotification stopMocking];
    [self.mockedUNNotificationContent stopMocking];
    [self.mockedUNNotificationRequest stopMocking];
    [self.mockedUNNotificationResponse stopMocking];

    [super tearDown];
}


/**
 * Test registering a device token.
 */
- (void)testRegisteredDeviceToken {
    NSData *token = [@"some-token" dataUsingEncoding:NSASCIIStringEncoding];

    // Expect analytics to receive a UADeviceRegistrationEvent event
    [[self.mockedAnalytics expect] addEvent:[OCMArg checkWithBlock:^BOOL(id obj) {
        return [obj isKindOfClass:[UADeviceRegistrationEvent class]];
    }]];

    // Expect UAPush to receive the device token
    [[self.mockedPush expect] application:self.mockedApplication didRegisterForRemoteNotificationsWithDeviceToken:token];

    // Call the app integration
    [UAAppIntegration application:self.mockedApplication didRegisterForRemoteNotificationsWithDeviceToken:token];

    // Verify everything
    [self.mockedAnalytics verify];
    [self.mockedPush verify];
}

/**
 * Test application:didFailToRegisterForRemoteNotificationsWithError .
 */
- (void)testFailedToRegisteredDeviceToken {
    NSError *error = [NSError errorWithDomain:@"domain" code:100 userInfo:nil];
    
    // Expect UAPush method to be called
    [[self.mockedPush expect] application:self.mockedApplication didFailToRegisterForRemoteNotificationsWithError:error];
    
    // Call the app integration
    [UAAppIntegration application:self.mockedApplication didFailToRegisterForRemoteNotificationsWithError:error];
    
    // Verify everything
    [self.mockedPush verify];
}

/**
 * Test userNotificationCenter:willPresentNotification:withCompletionHandler when automatic setup is enabled
 */
- (void)testWillPresentNotificationAutomaticSetupEnabled {

    __block BOOL completionHandlerCalled = NO;

    // Mock UAConfig instance to so we can return a mocked automatic setup
    id mockConfig = [self strictMockForClass:[UAConfig class]];
    [[[self.mockedAirship stub] andReturn:mockConfig] config];

    //Mock automatic setup to be enabled
    [[[mockConfig stub] andReturnValue:OCMOCK_VALUE(YES)] isAutomaticSetupEnabled];

    // Assume alert option
    UNNotificationPresentationOptions expectedOptions = UNNotificationPresentationOptionAlert;

    // Return expected options from presentationOptionsForNotification
    [[[self.mockedPush stub] andReturnValue:OCMOCK_VALUE(expectedOptions)] presentationOptionsForNotification:OCMOCK_ANY];

    // Reject any calls to UAActionRunner when automatic setup is enabled
    [[[self.mockedActionRunner reject] ignoringNonObjectArgs] runActionsWithActionValues:OCMOCK_ANY
                                                                               situation:0
                                                                                metadata:OCMOCK_ANY
                                                                       completionHandler:OCMOCK_ANY];

    // Reject any calls to UAPush when automatic setup is enabled
    [[self.mockedPush reject] handleRemoteNotification:OCMOCK_ANY foreground:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    // Call the integration
    [UAAppIntegration userNotificationCenter:self.mockedUserNotificationCenter
                     willPresentNotification:self.mockedUNNotification
                       withCompletionHandler:^(UNNotificationPresentationOptions options) {
                           completionHandlerCalled = YES;
                           // Check that completion handler is called with expected options
                           XCTAssertEqual(options, expectedOptions);
                       }];

    // Verify everything
    [self.mockedActionRunner verify];
    [self.mockedPush verify];
    XCTAssertTrue(completionHandlerCalled, @"Completion handler should be called.");
}

/**
 * Test userNotificationCenter:willPresentNotification:withCompletionHandler when automatic setup is disabled
 */
- (void)testWillPresentNotificationAutomaticSetupDisabled {

    __block BOOL completionHandlerCalled = NO;

    BOOL (^handlerCheck)(id obj) = ^(id obj) {
        void (^handler)(UAActionResult *) = obj;
        if (handler) {
            handler([UAActionResult emptyResult]);
        }
        return YES;
    };

    // Mock UAConfig instance to so we can return a mocked automatic setup
    id mockConfig = [self strictMockForClass:[UAConfig class]];
    [[[self.mockedAirship stub] andReturn:mockConfig] config];
    UNNotificationPresentationOptions expectedOptions = UNNotificationPresentationOptionAlert;

    //Mock automatic setup to be disabled
    [[[mockConfig stub] andReturnValue:OCMOCK_VALUE(NO)] isAutomaticSetupEnabled];

    //Expect UAPush call to presentationOptionsForNotification with the specified notification
    [[[self.mockedPush stub] andReturnValue:OCMOCK_VALUE(expectedOptions)] presentationOptionsForNotification:self.mockedUNNotification];

    NSDictionary *expectedMetadata = @{ UAActionMetadataForegroundPresentationKey: @((expectedOptions & UNNotificationPresentationOptionAlert) > 0),
                                        UAActionMetadataPushPayloadKey: self.notification };

    UASituation expectedSituation = UASituationForegroundPush;

    [[self.mockedActionRunner expect] runActionsWithActionValues:self.notification
                                                       situation:expectedSituation
                                                        metadata:expectedMetadata
                                               completionHandler:[OCMArg checkWithBlock:handlerCheck]];

    // Expect UAPush to be called when automatic setup is enabled
    [[self.mockedPush expect] handleRemoteNotification:[OCMArg checkWithBlock:^BOOL(id obj) {
        UANotificationContent *content = obj;
        return [content.notificationInfo isEqualToDictionary:self.notification];
    }] foreground:YES completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^handler)(UIBackgroundFetchResult) = obj;
        handler(UIBackgroundFetchResultNewData);
        return YES;
    }]];

    // Call the integration
    [UAAppIntegration userNotificationCenter:self.mockedUserNotificationCenter
                     willPresentNotification:self.mockedUNNotification
                       withCompletionHandler:^(UNNotificationPresentationOptions options) {
                           completionHandlerCalled = YES;
                           // Check that completion handler is called with expected options
                           XCTAssertEqual(options, expectedOptions);
                       }];

    // Verify everything
    [self.mockedActionRunner verify];
    [self.mockedPush verify];
    XCTAssertTrue(completionHandlerCalled, @"Completion handler should be called.");
}

/**
 * Tests userNotificationCenter:didReceiveNotificationResponse:completionHandler when
 * launched from push
 */
-(void)testDidReceiveNotificationResponseWithDefaultAction {

    __block BOOL completionHandlerCalled = NO;

    BOOL (^handlerCheck)(id obj) = ^(id obj) {
        completionHandlerCalled = YES;

        void (^handler)(UAActionResult *) = obj;
        if (handler) {
            handler([UAActionResult emptyResult]);
        }
        return YES;
    };

    // Mock the action idetifier to return UNNotificationDefaultActionIdentifier
    [[[self.mockedUNNotificationResponse stub] andReturn:UNNotificationDefaultActionIdentifier] actionIdentifier];

    // Default action is launched from push
    UASituation expectedSituation = UASituationLaunchedFromPush;

    NSDictionary *expectedMetadata = @{ UAActionMetadataPushPayloadKey:self.notification,
                                        UAActionMetadataUserNotificationActionIDKey:UNNotificationDefaultActionIdentifier};

    // Expect a call to UAActionRunner
    [[self.mockedActionRunner expect] runActionsWithActionValues:self.notification
                                                       situation:expectedSituation
                                                        metadata:expectedMetadata
                                               completionHandler:[OCMArg checkWithBlock:handlerCheck]];

    // Expect a call to UAPush
    [[self.mockedPush expect] handleNotificationResponse:[OCMArg checkWithBlock:^BOOL(id obj) {
        UANotificationResponse *response = obj;
        return [response.actionIdentifier isEqualToString:UANotificationDefaultActionIdentifier] &&
        [response.notificationContent.notificationInfo isEqualToDictionary:self.notification];
    }] completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^handler)(void) = obj;
        handler();
        return YES;
    }]];

    // Expect a call to UAAnalytics
    [[self.mockedAnalytics expect] launchedFromNotification:self.notification];

    // Call the integration
    [UAAppIntegration userNotificationCenter:self.mockedUserNotificationCenter
              didReceiveNotificationResponse:self.mockedUNNotificationResponse
                       withCompletionHandler:^{
                           completionHandlerCalled = YES;
                       }];

    // Verify everything
    [self.mockedActionRunner verify];
    [self.mockedPush verify];
    XCTAssertTrue(completionHandlerCalled, @"Completion handler should be called.");
}

/**
 * Tests userNotificationCenter:didReceiveNotificationResponse:completionHandler
 * with a foreground action
 */
-(void)testDidReceiveNotificationResponseWithForegroundAction {
    __block BOOL completionHandlerCalled = NO;

    BOOL (^handlerCheck)(id obj) = ^(id obj) {
        void (^handler)(UAActionResult *) = obj;
        if (handler) {
            handler([UAActionResult emptyResult]);
        }
        return YES;
    };

    UASituation expectedSituation = UASituationForegroundInteractiveButton;

    [[[self.mockedUNNotificationResponse stub] andReturn:@"foregroundIdentifier"] actionIdentifier];

    [[[self.mockedUANotificationContent stub] andReturn:@"notificationCategory"] categoryIdentifier];

    UANotificationAction *foregroundAction = [UANotificationAction actionWithIdentifier:@"foregroundIdentifier"
                                                                                  title:@"title"
                                                                                options:(UANotificationActionOptions)UNNotificationActionOptionForeground];

    UANotificationCategory *category = [UANotificationCategory categoryWithIdentifier:@"notificationCategory"
                                                                              actions:@[foregroundAction]
                                                                    intentIdentifiers:@[]
                                                                              options:0];

    [[[self.mockedPush stub] andReturn:[NSSet setWithArray:@[category]]] combinedCategories];

    UANotificationResponse *expectedAirshipResponse = [UANotificationResponse notificationResponseWithUNNotificationResponse:self.mockedUNNotificationResponse];
    NSMutableDictionary *expectedMetadata = [NSMutableDictionary dictionary];
    [expectedMetadata setValue:[expectedAirshipResponse actionIdentifier] forKey:UAActionMetadataUserNotificationActionIDKey];
    [expectedMetadata setValue:expectedAirshipResponse.notificationContent.notificationInfo forKey:UAActionMetadataPushPayloadKey];
    [expectedMetadata setValue:expectedAirshipResponse.responseText forKey:UAActionMetadataResponseInfoKey];

    // Expect a call to UAActionRunner
    [[self.mockedActionRunner expect] runActionsWithActionValues:self.notification[@"com.urbanairship.interactive_actions"][@"foregroundIdentifier"]
                                                       situation:expectedSituation
                                                        metadata:expectedMetadata
                                               completionHandler:[OCMArg checkWithBlock:handlerCheck]];



    // Expect a call to UAAnalytics
    [[self.mockedAnalytics expect] launchedFromNotification:self.notification];
    [[self.mockedAnalytics expect] addEvent:[OCMArg checkWithBlock:^BOOL(id obj) {
        return [obj isKindOfClass:[UAInteractiveNotificationEvent class]];
    }]];

    // Expect a call to UAPush
    [[self.mockedPush expect] handleNotificationResponse:[OCMArg checkWithBlock:^BOOL(id obj) {
        UANotificationResponse *response = obj;
        return [response.actionIdentifier isEqualToString:@"foregroundIdentifier"] &&
        [response.notificationContent.notificationInfo isEqualToDictionary:self.notification];
    }] completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^handler)(void) = obj;
        handler();
        return YES;
    }]];

    // Call the integration
    [UAAppIntegration userNotificationCenter:self.mockedUserNotificationCenter
              didReceiveNotificationResponse:self.mockedUNNotificationResponse
                       withCompletionHandler:^{
                           completionHandlerCalled = YES;

                       }];

    // Verify everything
    [self.mockedActionRunner verify];
    [self.mockedPush verify];
    [self.mockedAnalytics verify];
    XCTAssertTrue(completionHandlerCalled, @"Completion handler should be called.");
}

/**
 * Tests userNotificationCenter:didReceiveNotificationResponse:completionHandler
 * with a background action
 */
-(void)testDidReceiveNotificationResponseWithBackgroundAction {
    __block BOOL completionHandlerCalled = NO;

    BOOL (^handlerCheck)(id obj) = ^(id obj) {
        void (^handler)(UAActionResult *) = obj;
        if (handler) {
            handler([UAActionResult emptyResult]);
        }
        return YES;
    };

    UASituation expectedSituation = UASituationForegroundInteractiveButton;

    [[[self.mockedUNNotificationResponse stub] andReturn:@"backgroundIdentifier"] actionIdentifier];

    [[[self.mockedUANotificationContent stub] andReturn:@"notificationCategory"] categoryIdentifier];

    UANotificationAction *foregroundAction = [UANotificationAction actionWithIdentifier:@"backgroundIdentifier"
                                                                                  title:@"title"
                                                                                options:(UANotificationActionOptions)UNNotificationActionOptionForeground];

    UANotificationCategory *category = [UANotificationCategory categoryWithIdentifier:@"notificationCategory"
                                                                              actions:@[foregroundAction]
                                                                    intentIdentifiers:@[]
                                                                              options:0];

    [[[self.mockedPush stub] andReturn:[NSSet setWithArray:@[category]]] combinedCategories];

    UANotificationResponse *expectedAirshipResponse = [UANotificationResponse notificationResponseWithUNNotificationResponse:self.mockedUNNotificationResponse];
    NSMutableDictionary *expectedMetadata = [NSMutableDictionary dictionary];
    [expectedMetadata setValue:[expectedAirshipResponse actionIdentifier] forKey:UAActionMetadataUserNotificationActionIDKey];
    [expectedMetadata setValue:expectedAirshipResponse.notificationContent.notificationInfo forKey:UAActionMetadataPushPayloadKey];
    [expectedMetadata setValue:expectedAirshipResponse.responseText forKey:UAActionMetadataResponseInfoKey];

    // Expect a call to UAActionRunner
    [[self.mockedActionRunner expect] runActionsWithActionValues:self.notification[@"com.urbanairship.interactive_actions"][@"backgroundIdentifier"]
                                                       situation:expectedSituation
                                                        metadata:expectedMetadata
                                               completionHandler:[OCMArg checkWithBlock:handlerCheck]];

    // Expect a call to UAAnalytics
    [[self.mockedAnalytics expect] addEvent:[OCMArg checkWithBlock:^BOOL(id obj) {
        return [obj isKindOfClass:[UAInteractiveNotificationEvent class]];
    }]];

    // Expect a call to UAPush
    [[self.mockedPush expect] handleNotificationResponse:[OCMArg checkWithBlock:^BOOL(id obj) {
        UANotificationResponse *response = obj;
        return [response.actionIdentifier isEqualToString:@"backgroundIdentifier"] &&
        [response.notificationContent.notificationInfo isEqualToDictionary:self.notification];
    }] completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^handler)(void) = obj;
        handler();
        return YES;
    }]];

    // Call the integration
    [UAAppIntegration userNotificationCenter:self.mockedUserNotificationCenter
              didReceiveNotificationResponse:self.mockedUNNotificationResponse
                       withCompletionHandler:^{
                           completionHandlerCalled = YES;

                       }];

    // Verify everything
    [self.mockedActionRunner verify];
    [self.mockedPush verify];
    [self.mockedAnalytics verify];
    XCTAssertTrue(completionHandlerCalled, @"Completion handler should be called.");
}

/**
 * Tests userNotificationCenter:didReceiveNotificationResponse:completionHandler with
 * an unknown action
 */
-(void)testDidReceiveNotificationResponseUnknownAction {
    __block BOOL completionHandlerCalled = NO;

    [[[self.mockedUNNotificationResponse stub] andReturn:@"testActionIdentifier"] actionIdentifier];
    [[[self.mockedUNNotificationContent stub] andReturn:@"some_unknown_category"] categoryIdentifier];

    // Expect the UAPush to be called
    [[self.mockedPush expect] handleNotificationResponse:[OCMArg checkWithBlock:^BOOL(id obj) {
        UANotificationResponse *response = obj;
        return [response.actionIdentifier isEqualToString:@"testActionIdentifier"] &&
        [response.notificationContent.notificationInfo isEqualToDictionary:self.notification];
    }] completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^handler)(void) = obj;
        handler();
        return YES;
    }]];

    // Call the integration
    [UAAppIntegration userNotificationCenter:self.mockedUserNotificationCenter
              didReceiveNotificationResponse:self.mockedUNNotificationResponse
                       withCompletionHandler:^{

                           completionHandlerCalled = YES;

                       }];

    // Verify everything
    [self.mockedPush verify];
    XCTAssertTrue(completionHandlerCalled, @"Completion handler should be called.");
}

/**
 * Test application:didReceiveRemoteNotification:fetchCompletionHandler in the
 * foreground.
 */
- (void)testReceivedRemoteNotificationForeground {

    XCTestExpectation *handlerExpectation = [self expectationWithDescription:@"Completion handler called"];

    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateActive)] applicationState];

    __block BOOL completionHandlerCalled = NO;
    BOOL (^handlerCheck)(id obj) = ^(id obj) {
        void (^handler)(UAActionResult *) = obj;
        if (handler) {
            handler([UAActionResult emptyResult]);
        }
        return YES;
    };

    NSDictionary *expectedMetadata = @{ UAActionMetadataForegroundPresentationKey: @(NO),
                                        UAActionMetadataPushPayloadKey: self.notification };

    // Expect actions to be run for the action identifier
    [[self.mockedActionRunner expect] runActionsWithActionValues:self.notification
                                                       situation:UASituationForegroundPush
                                                        metadata:expectedMetadata
                                               completionHandler:[OCMArg checkWithBlock:handlerCheck]];

    // Expect the UAPush to be called
    [[self.mockedPush expect] handleRemoteNotification:[OCMArg checkWithBlock:^BOOL(id obj) {
        UANotificationContent *content = obj;
        return [content.notificationInfo isEqualToDictionary:self.notification];
    }] foreground:YES completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^handler)(UIBackgroundFetchResult) = obj;
        handler(UIBackgroundFetchResultNoData);
        return YES;
    }]];

    // Call the integration
    [UAAppIntegration application:self.mockedApplication
     didReceiveRemoteNotification:self.notification
           fetchCompletionHandler:^(UIBackgroundFetchResult result) {
               completionHandlerCalled = YES;
               XCTAssertEqual(result, UIBackgroundFetchResultNoData);
               [handlerExpectation fulfill];
           }];

    // Verify everything
    [self.mockedActionRunner verify];
    [self.mockedPush verify];
    [self waitForExpectationsWithTimeout:1 handler:nil];
    XCTAssertTrue(completionHandlerCalled, @"Completion handler should be called.");
}


/**
 * Test application:didReceiveRemoteNotification:fetchCompletionHandler in the
 * background when a message ID is present.
 */
- (void)testReceivedRemoteNotificationBackgroundWithMessageID {

    // Notification modified to include message ID
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
                          @"_uamid": @"rich push ID"
                          };

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
                                        UAActionMetadataPushPayloadKey: self.notification};

    NSDictionary *actionsPayload = [UAAppIntegration actionsPayloadForNotificationContent:
                                    [UANotificationContent notificationWithNotificationInfo:self.notification] actionIdentifier:nil];

    // Expect actions to be run for the action identifier
    [[self.mockedActionRunner expect] runActionsWithActionValues:actionsPayload
                                                       situation:UASituationBackgroundPush
                                                        metadata:expectedMetadata
                                               completionHandler:[OCMArg checkWithBlock:handlerCheck]];

    // Expect the UAPush to be called
    [[self.mockedPush expect] handleRemoteNotification:[OCMArg checkWithBlock:^BOOL(id obj) {
        UANotificationContent *content = obj;
        return [content.notificationInfo isEqualToDictionary:self.notification];
    }] foreground:NO completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^handler)(UIBackgroundFetchResult) = obj;
        handler(UIBackgroundFetchResultNewData);
        return YES;
    }]];

    // Expect a call to retrieve messages
    [[self.mockedMessageList expect] retrieveMessageListWithSuccessBlock:[OCMArg checkWithBlock:handlerCheck]
                                                        withFailureBlock:OCMOCK_ANY];

    // Call the integration
    [UAAppIntegration application:self.mockedApplication
     didReceiveRemoteNotification:self.notification
           fetchCompletionHandler:^(UIBackgroundFetchResult result) {
               completionHandlerCalled = YES;
               XCTAssertEqual(result, UIBackgroundFetchResultNewData);
               [handlerExpectation fulfill];
           }];

    // Verify everything
    [self waitForExpectationsWithTimeout:1 handler:^(NSError * _Nullable error) {
        if (error == nil) {
            [self.mockedMessageList verify];
            [self.mockedActionRunner verify];
            [self.mockedPush verify];
        }
    }];

    XCTAssertTrue(completionHandlerCalled, @"Completion handler should be called.");
}

/**
 * Test application:didReceiveRemoteNotification:fetchCompletionHandler in the
 * background when a message ID is not present.
 */
- (void)testReceivedRemoteNotificationBackgroundNoMessageID {

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
                                        UAActionMetadataPushPayloadKey: self.notification};

    NSDictionary *actionsPayload = [UAAppIntegration actionsPayloadForNotificationContent:
                                    [UANotificationContent notificationWithNotificationInfo:self.notification] actionIdentifier:nil];

    // Expect actions to be run for the action identifier
    [[self.mockedActionRunner expect] runActionsWithActionValues:actionsPayload
                                                       situation:UASituationBackgroundPush
                                                        metadata:expectedMetadata
                                               completionHandler:[OCMArg checkWithBlock:handlerCheck]];

    // Expect the UAPush to be called
    [[self.mockedPush expect] handleRemoteNotification:[OCMArg checkWithBlock:^BOOL(id obj) {
        UANotificationContent *content = obj;
        return [content.notificationInfo isEqualToDictionary:self.notification];
    }] foreground:NO completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^handler)(UIBackgroundFetchResult) = obj;
        handler(UIBackgroundFetchResultNewData);
        return YES;
    }]];

    // Reject a call to retrieve messages
    [[self.mockedMessageList reject] retrieveMessageListWithSuccessBlock:OCMOCK_ANY
                                                        withFailureBlock:OCMOCK_ANY];

    // Call the integration
    [UAAppIntegration application:self.mockedApplication
     didReceiveRemoteNotification:self.notification
           fetchCompletionHandler:^(UIBackgroundFetchResult result) {
               completionHandlerCalled = YES;
               XCTAssertEqual(result, UIBackgroundFetchResultNewData);
               [handlerExpectation fulfill];
           }];

    // Verify everything
    [self waitForExpectationsWithTimeout:1 handler:^(NSError * _Nullable error) {
        if (error == nil) {
            [self.mockedMessageList verify];
            [self.mockedActionRunner verify];
            [self.mockedPush verify];
        }
    }];

    XCTAssertTrue(completionHandlerCalled, @"Completion handler should be called.");
}

/**
 * Test application:didReceiveRemoteNotification:fetchCompletionHandler when
 * it's launching the application on iOS 10 treats it as a default notification
 * response.
 */
- (void)testReceivedRemoteNotificationLaunch {
    XCTestExpectation *handlerExpectation = [self expectationWithDescription:@"Completion handler called"];

    self.testOSMajorVersion = 10;
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateInactive)] applicationState];

    __block BOOL completionHandlerCalled = NO;
    BOOL (^handlerCheck)(id obj) = ^(id obj) {
        void (^handler)(UAActionResult *) = obj;
        if (handler) {
            handler([UAActionResult emptyResult]);
        }
        return YES;
    };

    NSDictionary *expectedMetadata = @{UAActionMetadataPushPayloadKey:self.notification,
                                       UAActionMetadataForegroundPresentationKey:@0};

    // Expect UAActionRunner to be called with actions to be run for the action identifier
    [[self.mockedActionRunner expect] runActionsWithActionValues:self.notification
                                                       situation:UASituationBackgroundPush
                                                        metadata:expectedMetadata
                                               completionHandler:[OCMArg checkWithBlock:handlerCheck]];


    // Expect UAPush to be called
    [[self.mockedPush expect] handleRemoteNotification:[OCMArg checkWithBlock:^BOOL(id obj) {
        UANotificationContent *content = obj;
        return [content.notificationInfo isEqualToDictionary:self.notification];
    }] foreground:NO completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^handler)(UIBackgroundFetchResult) = obj;
        handler(UIBackgroundFetchResultNewData);
        return YES;
    }]];

    // Call the integration
    [UAAppIntegration application:self.mockedApplication
     didReceiveRemoteNotification:self.notification
           fetchCompletionHandler:^(UIBackgroundFetchResult result) {
               completionHandlerCalled = YES;
               XCTAssertEqual(result, UIBackgroundFetchResultNewData);
               [handlerExpectation fulfill];
           }];

    // Verify everything
    //[self.mockedActionRunner verify];
    [self.mockedPush verify];
    [self waitForExpectationsWithTimeout:1 handler:nil];
    XCTAssertTrue(completionHandlerCalled, @"Completion handler should be called.");
}

/**
 * Test running actions for a push notification automatically adds a display inbox
 * action if the notification contains a message ID (_uamid).
 */
- (void)testPushActionsRunsInboxAction {
    NSDictionary *richPushNotification = @{@"_uamid": @"message_id", @"add_tags_action": @"tag"};

    // Expected actions payload
    NSMutableDictionary *expectedActionPayload = [NSMutableDictionary dictionaryWithDictionary:richPushNotification];

    // Should add the DisplayInboxAction
    expectedActionPayload[kUADisplayInboxActionDefaultRegistryAlias] = @"message_id";

    [[self.mockedActionRunner expect] runActionsWithActionValues:expectedActionPayload
                                                       situation:UASituationBackgroundPush
                                                        metadata:OCMOCK_ANY
                                               completionHandler:OCMOCK_ANY];

    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateInactive)] applicationState];


    // Call the integration
    [UAAppIntegration application:self.mockedApplication
     didReceiveRemoteNotification:richPushNotification
           fetchCompletionHandler:^(UIBackgroundFetchResult result) {
           }];

    // Verify everything
    [self.mockedActionRunner verify];
}

/**
 * Test running actions for a push notification does not add a inbox action if one is
 * already available.
 */
- (void)testPushActionsInboxActionAlreadyDefined {

    // Notification with a message ID and a Overlay Inbox Message Action
    NSDictionary *richPushNotification = @{@"_uamid": @"message_id", @"^mco": @"MESSAGE_ID",};

    // Expected actions payload
    NSMutableDictionary *expectedActionPayload = [NSMutableDictionary dictionaryWithDictionary:richPushNotification];
    
    [[self.mockedActionRunner expect] runActionsWithActionValues:expectedActionPayload
                                                       situation:UASituationBackgroundPush
                                                        metadata:OCMOCK_ANY
                                               completionHandler:OCMOCK_ANY];
    
    
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateInactive)] applicationState];
    
    
    // Call the integration
    [UAAppIntegration application:self.mockedApplication
     didReceiveRemoteNotification:richPushNotification
           fetchCompletionHandler:^(UIBackgroundFetchResult result) {
           }];
    
    // Verify everything
    [self.mockedActionRunner verify];
    
}

/**
 * Test background app refresh results in a call to update authorized notification types
 */
- (void)testDidReceiveBackgroundAppRefresh {
    self.testOSMajorVersion = 10;

    __block BOOL handlerCalled = false;

    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateBackground)] applicationState];


    [[self.mockedPush expect] updateAuthorizedNotificationTypes];


    [UAAppIntegration application:self.mockedApplication performFetchWithCompletionHandler:^(UIBackgroundFetchResult result) {

        handlerCalled = true;
    }];


    [self.mockedPush verify];
    XCTAssertTrue(handlerCalled);
}
@end
