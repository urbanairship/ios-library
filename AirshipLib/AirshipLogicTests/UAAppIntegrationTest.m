/*
 Copyright 2009-2016 Urban Airship Inc. All rights reserved.

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
#import "UAAnalytics.h"
#import "UAInteractiveNotificationEvent+Internal.h"
#import "UAPushReceivedEvent+Internal.h"
#import "UAActionRunner+Internal.h"
#import "UAActionRegistry+Internal.h"
#import "UADeviceRegistrationEvent+Internal.h"

@interface UAAppIntegrationTest : XCTestCase
@property (nonatomic, strong) id mockedApplication;
@property (nonatomic, strong) id mockedUserNotificationCenter;
@property (nonatomic, strong) id mockedAirship;
@property (nonatomic, strong) id mockedAnalytics;
@property (nonatomic, strong) id mockedPush;
@property (nonatomic, strong) id mockActionRunner;
@property (nonatomic, strong) id mockProcessInfo;

@property (nonatomic, assign) NSUInteger testOSMajorVersion;
@property (nonatomic, strong) NSDictionary *notification;

@end

@implementation UAAppIntegrationTest

- (void)setUp {
    [super setUp];

    self.testOSMajorVersion = 8;
    self.mockProcessInfo = [OCMockObject niceMockForClass:[NSProcessInfo class]];
    [[[self.mockProcessInfo stub] andReturn:self.mockProcessInfo] processInfo];

    [[[[self.mockProcessInfo stub] andDo:^(NSInvocation *invocation) {
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


    self.mockedAnalytics = [OCMockObject niceMockForClass:[UAAnalytics class]];
    self.mockedPush =[OCMockObject niceMockForClass:[UAPush class]];

    self.mockedAirship =[OCMockObject niceMockForClass:[UAirship class]];
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
}

- (void)tearDown {
    [self.mockedApplication stopMocking];
    [self.mockedAnalytics stopMocking];
    [self.mockedAirship stopMocking];
    [self.mockActionRunner stopMocking];
    [self.mockedPush stopMocking];
    [self.mockProcessInfo stopMocking];
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
 * Test application:handleActionWithIdentifier:forRemoteNotification:completionHandler
 * with a background action.
 */
- (void)testHandleBackgroundActionIdentifier {
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
    [[self.mockActionRunner expect] runActionsWithActionValues:self.notification[@"com.urbanairship.interactive_actions"][@"backgroundIdentifier"]
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
    [self.mockActionRunner verify];
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
    [[self.mockActionRunner expect] runActionsWithActionValues:self.notification[@"com.urbanairship.interactive_actions"][@"foregroundIdentifier"]
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
    [self.mockActionRunner verify];
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
    [[self.mockActionRunner expect] runActionsWithActionValues:self.notification[@"com.urbanairship.interactive_actions"][@"foregroundIdentifier"]
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
    [self.mockActionRunner verify];
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

    [[self.mockActionRunner reject] runActionsWithActionValues:OCMOCK_ANY
                                                     situation:UASituationForegroundInteractiveButton
                                                      metadata:OCMOCK_ANY
                                             completionHandler:OCMOCK_ANY];

    [[self.mockActionRunner reject] runActionsWithActionValues:OCMOCK_ANY
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
    [self.mockActionRunner verify];
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
    [[self.mockActionRunner expect] runActionsWithActionValues:self.notification
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
    [self.mockActionRunner verify];
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
    [[self.mockActionRunner expect] runActionsWithActionValues:self.notification
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
    [self.mockActionRunner verify];
    [self.mockedPush verify];
    XCTAssertTrue(completionHandlerCalled, @"Completion handler should be called.");
}

/**
 * Test application:didReceiveRemoteNotification:fetchCompletionHandler when
 * it launching the applicaiton on iOS 8 & 9 treats it as a default notification
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
    [[self.mockActionRunner expect] runActionsWithActionValues:self.notification
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
    [self.mockActionRunner verify];
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

    [[self.mockActionRunner expect]runActionsWithActionValues:expectedActionPayload
                                                    situation:UASituationLaunchedFromPush
                                                     metadata:OCMOCK_ANY
                                            completionHandler:OCMOCK_ANY];

    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateInactive)] applicationState];


    // Call the integration
    [UAAppIntegration application:self.mockedApplication
     didReceiveRemoteNotification:self.notification
           fetchCompletionHandler:^(UIBackgroundFetchResult result) {
           }];

    // Verify everything
    [self.mockActionRunner verify];
}

/**
 * Test running actions for a push notification does not add a inbox action if one is
 * already available.
 */
- (void)testPushActionsInboxActionAlreadyDefined {

    // Notification with a message ID and a Overlay Inbox Message Action
    NSDictionary *richPushNotification = @{@"_uamid": @"message_id", @"^mco": @"MESSAGE_ID"};

    // Expected actions payload
    NSMutableDictionary *expectedActionPayload = [NSMutableDictionary dictionaryWithDictionary:richPushNotification];

    [[self.mockActionRunner expect]runActionsWithActionValues:expectedActionPayload
                                                    situation:UASituationLaunchedFromPush
                                                     metadata:OCMOCK_ANY
                                            completionHandler:OCMOCK_ANY];


    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateInactive)] applicationState];


    // Call the integration
    [UAAppIntegration application:self.mockedApplication
     didReceiveRemoteNotification:self.notification
           fetchCompletionHandler:^(UIBackgroundFetchResult result) {
           }];

    // Verify everything
    [self.mockActionRunner verify];

}



@end
