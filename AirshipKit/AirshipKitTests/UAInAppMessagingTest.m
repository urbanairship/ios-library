/* Copyright 2017 Urban Airship and Contributors */

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "UAInAppMessaging+Internal.h"
#import "UAInAppmessage.h"
#import "UAInAppMessageController+Internal.h"
#import "UAirship+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAPush.h"
#import "UAAnalytics.h"
#import "UAActionRegistry.h"
#import "UADisplayInboxAction.h"

@interface UAInAppMessagingTest : XCTestCase
@property(nonatomic, strong) id mockAnalytics;
@property(nonatomic, strong) id mockMessageController;

@property(nonatomic, strong) UAPreferenceDataStore *dataStore;
@property(nonatomic, strong) UAInAppMessage *bannerMessage;
@property(nonatomic, strong) UAInAppMessage *nonBannerMessage;
@property(nonatomic, strong) UAInAppMessaging *inAppMessaging;
@property(nonatomic, strong) NSDictionary *payload;
@property(nonatomic, strong) NSDictionary *aps;

@end

@implementation UAInAppMessagingTest

- (void)setUp {
    [super setUp];

    self.dataStore = [UAPreferenceDataStore preferenceDataStoreWithKeyPrefix:@"UAInAppMessagingTest"];

    self.mockAnalytics = [OCMockObject niceMockForClass:[UAAnalytics class]];

    self.inAppMessaging = [UAInAppMessaging inAppMessagingWithAnalytics:self.mockAnalytics dataStore:self.dataStore];

    self.mockMessageController = [OCMockObject mockForClass:[UAInAppMessageController class]];
    [[[self.mockMessageController stub] andReturn:self.mockMessageController] controllerWithMessage:[OCMArg any] delegate:[OCMArg any] dismissalBlock:[OCMArg any]];

    self.bannerMessage = [UAInAppMessage message];
    self.bannerMessage.identifier = @"identifier";
    self.bannerMessage.alert = @"whatever";
    self.bannerMessage.displayType = UAInAppMessageDisplayTypeBanner;
    self.bannerMessage.expiry = [NSDate dateWithTimeIntervalSinceNow:10000];

    self.nonBannerMessage.alert = @"blah";
    self.nonBannerMessage.displayType = UAInAppMessageDisplayTypeUnknown;

    self.payload = @{
                     @"display": @{
                             @"alert": @"pending message alert",
                             @"duration": @40,
                             @"position": @"bottom",
                             @"primary_color": @"#ffff0000",
                             @"secondary_color": @"#ff000055",
                             @"type": @"banner"
                             },
                     @"expiry": @"2020-12-15T11:45:22",
                     @"identifier":@"send ID"
                     };

    self.aps = @{
                 @"aps": @{
                         @"alert": @"sample alert",
                         @"badge": @2,
                         @"sound": @"cat",
                         }
                 };
}

- (void)tearDown {
    [self.mockAnalytics stopMocking];
    [self.mockMessageController stopMocking];

    [self.dataStore removeAll];

    [super tearDown];
}

/**
 * Test that banner messages are displayed
 */
- (void)testDisplayBannerMessage {
    [(UAInAppMessageController *)[self.mockMessageController expect] show];

    [self.inAppMessaging displayMessage:self.bannerMessage];

    [self.mockMessageController verify];
}

/**
 * Test that non-banner messages are not displayed.
 */
- (void)testDisplayNonBannerMessage {
    [(UAInAppMessageController *)[self.mockMessageController reject] show];

    [self.inAppMessaging displayMessage:self.nonBannerMessage];

    [self.mockMessageController verify];
}

/**
 * Test that banner messages are stored.
 */
- (void)testStoreBannerPendingMessage {
    self.inAppMessaging.pendingMessage = self.bannerMessage;

    XCTAssertEqualObjects(self.inAppMessaging.pendingMessage.payload, self.bannerMessage.payload);
}

/**
 * Test that non-banner messages are not stored.
 */
- (void)testStoreNonBannerPendingMessage {
    self.inAppMessaging.pendingMessage = self.nonBannerMessage;

    XCTAssertNil(self.inAppMessaging.pendingMessage);
}

/**
 * Test display pending message tries to display the pending message.
 */
- (void)testDisplayPendingMessage {
    self.inAppMessaging.pendingMessage = self.bannerMessage;

    // Expect to show the message
    [(UAInAppMessageController *)[self.mockMessageController expect] show];

    // Trigger the message to be displayed
    [self.inAppMessaging displayPendingMessage];

    // Verify we actually tried to show a message
    [self.mockMessageController verify];
}

/**
 * Test auto display enabled persists in the data store.
 */
- (void)testAutoDisplayEnabled {
    XCTAssertTrue(self.inAppMessaging.isAutoDisplayEnabled);

    self.inAppMessaging.autoDisplayEnabled = NO;
    XCTAssertFalse(self.inAppMessaging.isAutoDisplayEnabled);


    // Verify it persists
    self.inAppMessaging = [UAInAppMessaging inAppMessagingWithAnalytics:self.mockAnalytics dataStore:self.dataStore];
    XCTAssertFalse(self.inAppMessaging.isAutoDisplayEnabled);
}

/**
 * Test that an event is added only if the messge is actually displayed
 */
- (void)testSendDisplayEventIfDisplayed {
    [(UAInAppMessageController *)[[self.mockMessageController stub] andReturnValue:OCMOCK_VALUE(YES)] show];

    [[self.mockAnalytics expect] addEvent:[OCMArg any]];
    [self.inAppMessaging displayMessage:self.bannerMessage];

    [self. mockAnalytics verify];

    [(UAInAppMessageController *)[[self.mockMessageController stub] andReturnValue:OCMOCK_VALUE(NO)] show];
    [[self.mockAnalytics reject] addEvent:[OCMArg any]];
    [self.mockAnalytics verify];
}

/**
 * Test notification response that contains an in-app message clears the pending message.
 */
- (void)testHandleNotificationResponse {
    XCTAssertNil([self.inAppMessaging pendingMessage]);

    [self.inAppMessaging setPendingMessage:[UAInAppMessage messageWithPayload:self.payload]];
    XCTAssertNotNil([self.inAppMessaging pendingMessage]);

    NSDictionary *notification = @{
                                   @"_": @"send ID",
                                   @"aps": self.aps,
                                   @"com.urbanairship.in_app": self.payload
                                   };

    UANotificationResponse *response = [UANotificationResponse notificationResponseWithNotificationInfo:notification
                                                                                       actionIdentifier:UANotificationDefaultActionIdentifier
                                                                                           responseText:nil];

    [[self.mockAnalytics expect] addEvent:[OCMArg any]];
    [self.inAppMessaging handleNotificationResponse:response];

    [self. mockAnalytics verify];
    XCTAssertNil([self.inAppMessaging pendingMessage]);
}

/**
 * Test notification response no-ops when it does not contain an in-app message.
 */
- (void)testHandleNotificationResponseNoInApp {
    XCTAssertNil([self.inAppMessaging pendingMessage]);

    [self.inAppMessaging setPendingMessage:[UAInAppMessage messageWithPayload:self.payload]];
    XCTAssertNotNil([self.inAppMessaging pendingMessage]);

    NSDictionary *notification = @{
                                   @"_": @"send ID",
                                   @"aps": self.aps
                                   };

    UANotificationResponse *response = [UANotificationResponse notificationResponseWithNotificationInfo:notification
                                                                                       actionIdentifier:UANotificationDefaultActionIdentifier
                                                                                           responseText:nil];

    [[self.mockAnalytics reject] addEvent:[OCMArg any]];
    [self.inAppMessaging handleNotificationResponse:response];

    [self.mockAnalytics verify];
    XCTAssertNotNil([self.inAppMessaging pendingMessage]);
}

/**
 * Test notification response no-ops when the response's in-app message does
 * not match the pending in-app message.
 */
- (void)testHandleNotificationResponseDifferentPendingMessage {
    XCTAssertNil([self.inAppMessaging pendingMessage]);

    [self.inAppMessaging setPendingMessage:[UAInAppMessage messageWithPayload:self.payload]];
    XCTAssertNotNil([self.inAppMessaging pendingMessage]);

    NSDictionary *notification = @{
                                   @"_": @"some identifier",
                                   @"aps": self.aps,
                                   @"com.urbanairship.in_app": @{
                                           @"display": @{
                                                   @"alert": @"new message alert",
                                                   @"duration": @40,
                                                   @"position": @"bottom",
                                                   @"primary_color": @"#ffff0000",
                                                   @"secondary_color": @"#ff000055",
                                                   @"type": @"banner"
                                                   },
                                           @"expiry": @"2020-12-15T11:45:22",
                                           }
                                   };

    UANotificationResponse *response = [UANotificationResponse notificationResponseWithNotificationInfo:notification
                                                                                       actionIdentifier:UANotificationDefaultActionIdentifier
                                                                                           responseText:nil];

    [[self.mockAnalytics reject] addEvent:[OCMArg any]];
    [self.inAppMessaging handleNotificationResponse:response];

    [self.mockAnalytics verify];
    XCTAssertNotNil([self.inAppMessaging pendingMessage]);
}

/**
 * Test remote notifications that contains an in-app message saves it as a pending
 * message.
 */
- (void)testHandleRemoteNotification {
    XCTAssertNil([self.inAppMessaging pendingMessage]);

    NSDictionary *notification = @{
                                   @"_": @"send ID",
                                   @"aps": self.aps,
                                   @"com.urbanairship.in_app": self.payload
                                   };

    UANotificationResponse *response = [UANotificationResponse notificationResponseWithNotificationInfo:notification
                                                                                       actionIdentifier:UANotificationDefaultActionIdentifier
                                                                                           responseText:nil];

    [self.inAppMessaging handleRemoteNotification:response.notificationContent];
    XCTAssertNotNil([self.inAppMessaging pendingMessage]);
}

/**
 * Test handling a remote notification no-ops when it does not contain an in-app message.
 */
- (void)testHandleRemoteNotificationNoInApp {
    XCTAssertNil([self.inAppMessaging pendingMessage]);

    NSDictionary *notification = @{
                                   @"_": @"send ID",
                                   @"aps": self.aps
                                   };

    UANotificationResponse *response = [UANotificationResponse notificationResponseWithNotificationInfo:notification
                                                                                       actionIdentifier:UANotificationDefaultActionIdentifier
                                                                                           responseText:nil];

    [self.inAppMessaging handleRemoteNotification:response.notificationContent];
    XCTAssertNil([self.inAppMessaging pendingMessage]);
}

/**
 * Test remote notifications that contains an in-app message and a message center
 * message appends an inbox action to the in-app message.
 */
- (void)testHandleRemoteNotificationWithMCRAP {
    XCTAssertNil([self.inAppMessaging pendingMessage]);

    NSDictionary *notification = @{
                                   @"_": @"send ID",
                                   @"_uamid": @"some message ID",
                                   @"aps": self.aps,
                                   @"com.urbanairship.in_app": self.payload
                                   };

    UANotificationResponse *response = [UANotificationResponse notificationResponseWithNotificationInfo:notification
                                                                                       actionIdentifier:UANotificationDefaultActionIdentifier
                                                                                           responseText:nil];

    [self.inAppMessaging handleRemoteNotification:response.notificationContent];
    XCTAssertNotNil([self.inAppMessaging pendingMessage]);
    BOOL containsOpenInboxAction = [self.inAppMessaging pendingMessage].onClick[kUADisplayInboxActionDefaultRegistryName] ||
    [self.inAppMessaging pendingMessage].onClick[kUADisplayInboxActionDefaultRegistryAlias];
    XCTAssertTrue(containsOpenInboxAction);
}

/**
 * Test remote notifications that contains an in-app message and a message center
 * does not append an inbox action if one already exists.
 */
- (void)testHandleRemoteNotificationWithMCRAPExistingInboxAction {
    XCTAssertNil([self.inAppMessaging pendingMessage]);

    id existingOpenInboxAction = @{ @"on_click": @{ @"^mc": @"AUTO" }};

    NSMutableDictionary *payload = [NSMutableDictionary dictionaryWithDictionary:self.payload];
    payload[@"actions"] = existingOpenInboxAction;

    NSDictionary *notification = @{
                                   @"_": @"send ID",
                                   @"_uamid": @"some message ID",
                                   @"aps": self.aps,
                                   @"com.urbanairship.in_app": payload
                                   };

    UANotificationResponse *response = [UANotificationResponse notificationResponseWithNotificationInfo:notification
                                                                                       actionIdentifier:UANotificationDefaultActionIdentifier
                                                                                           responseText:nil];

    [self.inAppMessaging handleRemoteNotification:response.notificationContent];
    XCTAssertEqualObjects([self.inAppMessaging pendingMessage].onClick[@"^mc"], @"AUTO");
}

@end
