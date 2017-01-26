/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "UAAppIntegration.h"
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

@interface UAAppIntegrationTest : XCTestCase
@property (nonatomic, strong) id mockedApplication;
@property (nonatomic, strong) id mockedUserNotificationCenter;
@property (nonatomic, strong) id mockedAirship;
@property (nonatomic, strong) id mockedAnalytics;
@property (nonatomic, strong) id mockedPush;
@property (nonatomic, strong) id mockedActionRunner;
@property (nonatomic, strong) id mockedProcessInfo;

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
    self.mockedProcessInfo = [OCMockObject niceMockForClass:[NSProcessInfo class]];
    [[[self.mockedProcessInfo stub] andReturn:self.mockedProcessInfo] processInfo];

    [[[[self.mockedProcessInfo stub] andDo:^(NSInvocation *invocation) {
        NSOperatingSystemVersion arg;
        [invocation getArgument:&arg atIndex:2];

        BOOL result = self.testOSMajorVersion >= arg.majorVersion;
        [invocation setReturnValue:&result];
    }] ignoringNonObjectArgs] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){0, 0, 0}];

    // Set up a mocked application
    self.mockedApplication = [OCMockObject niceMockForClass:[UIApplication class]];
    [[[self.mockedApplication stub] andReturn:self.mockedApplication] sharedApplication];

    // Set up mocked User Notification Center
    self.mockedUserNotificationCenter = [OCMockObject niceMockForClass:[UNUserNotificationCenter class]];
    [[[self.mockedUserNotificationCenter stub] andReturn:self.mockedUserNotificationCenter] currentNotificationCenter];

    self.mockedActionRunner = [OCMockObject mockForClass:[UAActionRunner class]];

    self.mockedAnalytics = [OCMockObject niceMockForClass:[UAAnalytics class]];
    self.mockedPush =[OCMockObject niceMockForClass:[UAPush class]];

    self.mockedAirship = [OCMockObject niceMockForClass:[UAirship class]];
    [[[self.mockedAirship stub] andReturn:self.mockedAirship] shared];
    [[[self.mockedAirship stub] andReturn:self.mockedAnalytics] analytics];
    [[[self.mockedAirship stub] andReturn:self.mockedPush] push];

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
    self.mockedUANotificationContent = [OCMockObject niceMockForClass:[UANotificationContent class]];
    [[[self.mockedUANotificationContent stub] andReturn:self.mockedUANotificationContent] notificationWithUNNotification:OCMOCK_ANY];
    [[[self.mockedUANotificationContent stub] andReturn:self.notification] notificationInfo];

    self.mockedUNNotification = [OCMockObject niceMockForClass:[UNNotification class]];
    self.mockedUNNotificationRequest = [OCMockObject niceMockForClass:[UNNotificationRequest class]];
    self.mockedUNNotificationContent = [OCMockObject niceMockForClass:[UNNotificationContent class]];

    [[[self.mockedUNNotification stub] andReturn:self.mockedUNNotificationRequest] request];
    [[[self.mockedUNNotificationRequest stub] andReturn:self.mockedUNNotificationContent] content];
    [[[self.mockedUNNotificationContent stub] andReturn:self.notification] userInfo];

    self.mockedUNNotificationResponse = [OCMockObject niceMockForClass:[UNNotificationResponse class]];
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

    [self.mockedUANotificationContent stopMocking];
    [self.mockedUNNotification stopMocking];
    [self.mockedUNNotificationContent stopMocking];
    [self.mockedUNNotificationRequest stopMocking];
    [self.mockedUNNotificationResponse stopMocking];

    [super tearDown];
}


/**
 * Test registering a device token in the background.
 */
- (void)testRegisteredDeviceTokenBackground {
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateBackground)] applicationState];

    NSData *token = [@"some-token" dataUsingEncoding:NSASCIIStringEncoding];

    // Expect analytics to receive a UADeviceRegistrationEvent event
    [[self.mockedAnalytics expect] addEvent:[OCMArg checkWithBlock:^BOOL(id obj) {
        return [obj isKindOfClass:[UADeviceRegistrationEvent class]];
    }]];

    // Expect UAPush to receive the device token string
    // 736f6d652d746f6b656e = "some-token" in hex
    [[self.mockedPush expect] setDeviceToken:@"736f6d652d746f6b656e"];

    // Call the app integration
    [UAAppIntegration application:self.mockedApplication didRegisterForRemoteNotificationsWithDeviceToken:token];

    // Verify everything
    [self.mockedAnalytics verify];
    [self.mockedPush verify];
}


/**
 * Test application:didRegisterForRemoteNotificationsWithDeviceToken in the foreground.
 */
- (void)testRegisteredDeviceTokenForeground {
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateActive)] applicationState];

    NSData *token = [@"some-token" dataUsingEncoding:NSASCIIStringEncoding];

    // Expect analytics to receive a UADeviceRegistrationEvent event
    [[self.mockedAnalytics expect] addEvent:[OCMArg checkWithBlock:^BOOL(id obj) {
        return [obj isKindOfClass:[UADeviceRegistrationEvent class]];
    }]];

    // Expect UAPush to receive the device token string
    // 736f6d652d746f6b656e = "some-token" in hex
    [[self.mockedPush expect] setDeviceToken:@"736f6d652d746f6b656e"];

    // Expect UAPush to update its registration
    [[self.mockedPush expect] updateChannelRegistrationForcefully:NO];

    // Call the app integration
    [UAAppIntegration application:self.mockedApplication didRegisterForRemoteNotificationsWithDeviceToken:token];

    // Verify everything
    [self.mockedAnalytics verify];
    [self.mockedPush verify];
}

/**
 * Test application:didRegisterUserNotificationSettings.
 */
- (void)testRegisterNotificationSettings {

    // Expect push to update its authorized notification types
    [[self.mockedPush expect] updateAuthorizedNotificationTypes];

    // Expect the application to register for remote notifications
    [[self.mockedApplication expect] registerForRemoteNotifications];

    // Call the app integration
    UIUserNotificationSettings *settings = [[UIUserNotificationSettings alloc] init];
    [UAAppIntegration application:self.mockedApplication didRegisterUserNotificationSettings:settings];

    // Verify everything
    [self.mockedPush verify];
    [self.mockedApplication verify];
}

/**
 * Test userNotificationCenter:willPresentNotification:withCompletionHandler when automatic setup is enabled
 */
- (void)testWillPresentNotificationAutomaticSetupEnabled {

    __block BOOL completionHandlerCalled = NO;

    // Mock UAConfig instance to so we can return a mocked automatic setup
    id mockConfig = [OCMockObject mockForClass:[UAConfig class]];
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
    id mockConfig = [OCMockObject mockForClass:[UAConfig class]];
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
        void (^handler)() = obj;
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
                                                                                options:UNNotificationActionOptionForeground];

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
        void (^handler)() = obj;
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
                                                                                options:UNNotificationActionOptionForeground];

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
        void (^handler)() = obj;
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
        void (^handler)() = obj;
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
 * Test application:handleActionWithIdentifier:forRemoteNotification:completionHandler
 * with a background action.
 */
- (void)testHandleBackgroundActionIdentifier {
    UANotificationAction *foregroundAction = [UANotificationAction actionWithIdentifier:@"foregroundIdentifier"
                                                                                  title:@"title"
                                                                                options:UNNotificationActionOptionForeground];
    UANotificationAction *backgroundAction = [UANotificationAction actionWithIdentifier:@"backgroundIdentifier"
                                                                                  title:@"title"
                                                                                options:0];

    UANotificationCategory *category = [UANotificationCategory categoryWithIdentifier:@"notificationCategory"
                                                                              actions:@[foregroundAction, backgroundAction]
                                                                    intentIdentifiers:@[]
                                                                              options:0];

    [[[self.mockedPush stub] andReturn:[NSSet setWithArray:@[category]]] combinedCategories];

    __block BOOL completionHandlerCalled = NO;

    BOOL (^handlerCheck)(id obj) = ^(id obj) {
        void (^handler)(UAActionResult *) = obj;
        if (handler) {
            handler([UAActionResult emptyResult]);
        }
        return YES;
    };

    // Expect actions to be run for the action identifier
    [[self.mockedActionRunner expect] runActionsWithActionValues:self.notification[@"com.urbanairship.interactive_actions"][@"backgroundIdentifier"]
                                                       situation:UASituationBackgroundInteractiveButton
                                                        metadata: @{ UAActionMetadataUserNotificationActionIDKey: @"backgroundIdentifier",
                                                                     UAActionMetadataPushPayloadKey: self.notification }
                                               completionHandler:[OCMArg checkWithBlock:handlerCheck]];


    // Expect UAInteractiveNotificationEvent to be added
    [[self.mockedAnalytics expect] addEvent:[OCMArg checkWithBlock:^BOOL(id obj) {
        return [obj isKindOfClass:[UAInteractiveNotificationEvent class]];
    }]];


    // Expect the UAPush to be called
    [[self.mockedPush expect] handleNotificationResponse:[OCMArg checkWithBlock:^BOOL(id obj) {
        UANotificationResponse *response = obj;
        return [response.actionIdentifier isEqualToString:@"backgroundIdentifier"] &&
        [response.notificationContent.notificationInfo isEqualToDictionary:self.notification];
    }] completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^handler)() = obj;
        handler();
        return YES;
    }]];

    // Call the integration
    [UAAppIntegration application:self.mockedApplication
       handleActionWithIdentifier:@"backgroundIdentifier"
            forRemoteNotification:self.notification completionHandler:^{
                completionHandlerCalled = YES;
            }];


    // Verify everything
    [self.mockedActionRunner verify];
    [self.mockedAnalytics verify];
    [self.mockedPush verify];
    XCTAssertTrue(completionHandlerCalled, @"Completion handler should be called.");
}

/**
 * Test application:handleActionWithIdentifier:forRemoteNotification:completionHandler
 * with a foreground action.
 */
- (void)testHandleForgroundActionIdentifier {
    UANotificationAction *foregroundAction = [UANotificationAction actionWithIdentifier:@"foregroundIdentifier" title:@"title" options:UNNotificationActionOptionForeground];
    UANotificationAction *backgroundAction = [UANotificationAction actionWithIdentifier:@"backgroundIdentifier" title:@"title" options:0];

    UANotificationCategory *category = [UANotificationCategory categoryWithIdentifier:@"notificationCategory"
                                                                              actions:@[foregroundAction, backgroundAction]
                                                                    intentIdentifiers:@[]
                                                                              options:0];

    [[[self.mockedPush stub] andReturn:[NSSet setWithArray:@[category]]] combinedCategories];

    __block BOOL completionHandlerCalled = NO;

    BOOL (^handlerCheck)(id obj) = ^(id obj) {
        void (^handler)(UAActionResult *) = obj;
        if (handler) {
            handler([UAActionResult emptyResult]);
        }
        return YES;
    };

    // Expect actions to be run for the action identifier
    [[self.mockedActionRunner expect] runActionsWithActionValues:self.notification[@"com.urbanairship.interactive_actions"][@"foregroundIdentifier"]
                                                       situation:UASituationForegroundInteractiveButton
                                                        metadata: @{ UAActionMetadataUserNotificationActionIDKey: @"foregroundIdentifier",
                                                                     UAActionMetadataPushPayloadKey: self.notification }
                                               completionHandler:[OCMArg checkWithBlock:handlerCheck]];


    // Expect UAInteractiveNotificationEvent to be added
    [[self.mockedAnalytics expect] addEvent:[OCMArg checkWithBlock:^BOOL(id obj) {
        return [obj isKindOfClass:[UAInteractiveNotificationEvent class]];
    }]];


    // Expect the UAPush to be called
    [[self.mockedPush expect] handleNotificationResponse:[OCMArg checkWithBlock:^BOOL(id obj) {
        UANotificationResponse *response = obj;
        return [response.actionIdentifier isEqualToString:@"foregroundIdentifier"] &&
        [response.notificationContent.notificationInfo isEqualToDictionary:self.notification];
    }] completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^handler)() = obj;
        handler();
        return YES;
    }]];

    // Call the integration
    [UAAppIntegration application:self.mockedApplication
       handleActionWithIdentifier:@"foregroundIdentifier"
            forRemoteNotification:self.notification completionHandler:^{
                completionHandlerCalled = YES;
            }];


    // Verify everything
    [self.mockedActionRunner verify];
    [self.mockedAnalytics verify];
    [self.mockedPush verify];
    XCTAssertTrue(completionHandlerCalled, @"Completion handler should be called.");
}

/**
 * Test application:handleActionWithIdentifier:forRemoteNotification:withResponseInfo:completionHandler.
 */
- (void)testHandleActionIdentifierWithResponseInfo {
    UANotificationAction *foregroundAction = [UANotificationAction actionWithIdentifier:@"foregroundIdentifier" title:@"title" options:UNNotificationActionOptionForeground];
    UANotificationAction *backgroundAction = [UANotificationAction actionWithIdentifier:@"backgroundIdentifier" title:@"title" options:0];

    UANotificationCategory *category = [UANotificationCategory categoryWithIdentifier:@"notificationCategory"
                                                                              actions:@[foregroundAction, backgroundAction]
                                                                    intentIdentifiers:@[]
                                                                              options:0];

    [[[self.mockedPush stub] andReturn:[NSSet setWithArray:@[category]]] combinedCategories];

    NSDictionary *responseInfo = @{@"UIUserNotificationActionResponseTypedTextKey":@"howdy"};
    NSDictionary *expectedMetadata = @{ UAActionMetadataUserNotificationActionIDKey: @"foregroundIdentifier",
                                        UAActionMetadataResponseInfoKey: @"howdy",
                                        UAActionMetadataPushPayloadKey: self.notification };


    __block BOOL completionHandlerCalled = NO;
    BOOL (^handlerCheck)(id obj) = ^(id obj) {
        void (^handler)(UAActionResult *) = obj;
        if (handler) {
            handler([UAActionResult emptyResult]);
        }
        return YES;
    };

    // Expect actions to be run for the action identifier
    [[self.mockedActionRunner expect] runActionsWithActionValues:self.notification[@"com.urbanairship.interactive_actions"][@"foregroundIdentifier"]
                                                       situation:UASituationForegroundInteractiveButton
                                                        metadata:expectedMetadata
                                               completionHandler:[OCMArg checkWithBlock:handlerCheck]];


    // Expect UAInteractiveNotificationEvent to be added
    [[self.mockedAnalytics expect] addEvent:[OCMArg checkWithBlock:^BOOL(id obj) {
        return [obj isKindOfClass:[UAInteractiveNotificationEvent class]];
    }]];


    // Expect the UAPush to be called
    [[self.mockedPush expect] handleNotificationResponse:[OCMArg checkWithBlock:^BOOL(id obj) {
        UANotificationResponse *response = obj;

        return [response.actionIdentifier isEqualToString:@"foregroundIdentifier"] &&
        [response.notificationContent.notificationInfo isEqualToDictionary:self.notification] &&
        [response.responseText isEqualToString:@"howdy"];

    }] completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^handler)() = obj;
        handler();
        return YES;
    }]];

    // Call the integration
    [UAAppIntegration application:self.mockedApplication
       handleActionWithIdentifier:@"foregroundIdentifier"
            forRemoteNotification:self.notification
                 withResponseInfo:responseInfo
                completionHandler:^{
                    completionHandlerCalled = YES;
                }];


    // Verify everything
    [self.mockedActionRunner verify];
    [self.mockedAnalytics verify];
    [self.mockedPush verify];
    XCTAssertTrue(completionHandlerCalled, @"Completion handler should be called.");
}


/**
 * Test application:handleActionWithIdentifier:forRemoteNotification:completionHandler
 * for an unknown action identifier.
 */
- (void)testHandleUnkownActionIdentifier {
    __block BOOL completionHandlerCalled = NO;

    [[self.mockedActionRunner reject] runActionsWithActionValues:OCMOCK_ANY
                                                       situation:UASituationForegroundInteractiveButton
                                                        metadata:OCMOCK_ANY
                                               completionHandler:OCMOCK_ANY];

    [[self.mockedActionRunner reject] runActionsWithActionValues:OCMOCK_ANY
                                                       situation:UASituationBackgroundInteractiveButton
                                                        metadata:OCMOCK_ANY
                                               completionHandler:OCMOCK_ANY];

    [[self.mockedAnalytics reject] addEvent:[OCMArg checkWithBlock:^BOOL(id obj) {
        return [obj isKindOfClass:[UAInteractiveNotificationEvent class]];
    }]];

    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateActive)] applicationState];

    // Expect UAPush to be called
    [[self.mockedPush expect] handleNotificationResponse:[OCMArg checkWithBlock:^BOOL(id obj) {
        UANotificationResponse *response = obj;

        return [response.actionIdentifier isEqualToString:@"foregroundIdentifier"] &&
        [response.notificationContent.notificationInfo isEqualToDictionary:self.notification];

    }] completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^handler)() = obj;
        handler();
        return YES;
    }]];


    // Call the integration
    [UAAppIntegration application:self.mockedApplication
       handleActionWithIdentifier:@"foregroundIdentifier"
            forRemoteNotification:self.notification
                completionHandler:^{
                    completionHandlerCalled = YES;
                }];


    // Verify everything
    [self.mockedActionRunner verify];
    [self.mockedAnalytics verify];
    [self.mockedPush verify];
    XCTAssertTrue(completionHandlerCalled, @"Completion handler should be called.");
}


/**
 * Test application:didReceiveRemoteNotification:fetchCompletionHandler in the
 * foreground.
 */
- (void)testReceivedRemoteNotificationForeground {

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
           }];

    // Verify everything
    [self.mockedActionRunner verify];
    [self.mockedPush verify];
    XCTAssertTrue(completionHandlerCalled, @"Completion handler should be called.");
}


/**
 * Test application:didReceiveRemoteNotification:fetchCompletionHandler in the
 * background.
 */
- (void)testReceivedRemoteNotificationBackground{
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateBackground)] applicationState];

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

    // Call the integration
    [UAAppIntegration application:self.mockedApplication
     didReceiveRemoteNotification:self.notification
           fetchCompletionHandler:^(UIBackgroundFetchResult result) {
               completionHandlerCalled = YES;
               XCTAssertEqual(result, UIBackgroundFetchResultNewData);
           }];

    // Verify everything
    [self.mockedActionRunner verify];
    [self.mockedPush verify];
    XCTAssertTrue(completionHandlerCalled, @"Completion handler should be called.");
}

/**
 * Test application:didReceiveRemoteNotification:fetchCompletionHandler when
 * it's launching the application on iOS 10 treats it as a default notification
 * response.
 */
- (void)testReceivedRemoteNotificationLaunch {
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
           }];

    // Verify everything
    //[self.mockedActionRunner verify];
    [self.mockedPush verify];
    XCTAssertTrue(completionHandlerCalled, @"Completion handler should be called.");
}

/**
 * Test application:didReceiveRemoteNotification:fetchCompletionHandler when
 * it's launching the application on iOS 8 & 9 treats it as a default notification
 * response.
 */
- (void)testReceivedRemoteNotificationLaunchLegacyOS {
    self.testOSMajorVersion = 9;
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateInactive)] applicationState];

    __block BOOL completionHandlerCalled = NO;
    BOOL (^handlerCheck)(id obj) = ^(id obj) {
        void (^handler)(UAActionResult *) = obj;
        if (handler) {
            handler([UAActionResult emptyResult]);
        }
        return YES;
    };

    NSDictionary *expectedMetadata = @{ UAActionMetadataUserNotificationActionIDKey: UANotificationDefaultActionIdentifier,
                                        UAActionMetadataPushPayloadKey: self.notification };

    // Expect actions to be run for the action identifier
    [[self.mockedActionRunner expect] runActionsWithActionValues:self.notification
                                                       situation:UASituationLaunchedFromPush
                                                        metadata:expectedMetadata
                                               completionHandler:[OCMArg checkWithBlock:handlerCheck]];

    // Expect the UAPush to be called
    [[self.mockedPush expect] handleNotificationResponse:[OCMArg checkWithBlock:^BOOL(id obj) {
        UANotificationResponse *response = obj;

        return [response.actionIdentifier isEqualToString:UANotificationDefaultActionIdentifier] &&
        [response.notificationContent.notificationInfo isEqualToDictionary:self.notification];

    }] completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^handler)() = obj;
        handler();
        return YES;
    }]];

    // Call the integration
    [UAAppIntegration application:self.mockedApplication
     didReceiveRemoteNotification:self.notification
           fetchCompletionHandler:^(UIBackgroundFetchResult result) {
               completionHandlerCalled = YES;
               XCTAssertEqual(result, UIBackgroundFetchResultNoData);
           }];

    // Verify everything
    [self.mockedActionRunner verify];
    [self.mockedPush verify];
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

@end
