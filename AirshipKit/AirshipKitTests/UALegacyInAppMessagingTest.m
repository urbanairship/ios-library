/* Copyright 2017 Urban Airship and Contributors */

#import <UIKit/UIKit.h>
#import "UABaseTest.h"
#import "UALegacyInAppMessaging+Internal.h"
#import "UALegacyInAppMessage.h"
#import "UAInAppMessageManager.h"
#import "UAirship+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAPush.h"
#import "UAAnalytics.h"
#import "UAActionRegistry.h"
#import "UADisplayInboxAction.h"
#import "UAInAppMessageBannerDisplayContent.h"
#import "UAScheduleInfo+Internal.h"
#import "UASchedule+Internal.h"

@interface UALegacyInAppMessagingTest : UABaseTest
@property(nonatomic, strong) id mockAnalytics;
@property(nonatomic, strong) id mockInAppMessageManager;

@property(nonatomic, strong) UAPreferenceDataStore *dataStore;
@property(nonatomic, strong) UALegacyInAppMessage *bannerMessage;
@property(nonatomic, strong) UALegacyInAppMessage *nonBannerMessage;
@property(nonatomic, strong) UALegacyInAppMessaging *inAppMessaging;
@property(nonatomic, strong) NSDictionary *payload;
@property(nonatomic, strong) NSDictionary *aps;

@end

@implementation UALegacyInAppMessagingTest

- (void)setUp {
    [super setUp];

    self.dataStore = [UAPreferenceDataStore preferenceDataStoreWithKeyPrefix:@"UALegacyInAppMessagingTest"];

    self.mockAnalytics = [self mockForClass:[UAAnalytics class]];
    self.mockInAppMessageManager = [self mockForClass:[UAInAppMessageManager class]];

    self.inAppMessaging = [UALegacyInAppMessaging inAppMessagingWithAnalytics:self.mockAnalytics dataStore:self.dataStore inAppMessageManager:self.mockInAppMessageManager];

    self.bannerMessage = [UALegacyInAppMessage message];
    self.bannerMessage.identifier = @"identifier";
    self.bannerMessage.alert = @"whatever";
    self.bannerMessage.displayType = UALegacyInAppMessageDisplayTypeBanner;
    self.bannerMessage.expiry = [NSDate dateWithTimeIntervalSinceNow:10000];

    self.nonBannerMessage.alert = @"blah";
    self.nonBannerMessage.displayType = UALegacyInAppMessageDisplayTypeUnknown;

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
    [self.mockInAppMessageManager stopMocking];

    [self.dataStore removeAll];

    [super tearDown];
}

/**
 * Test that banner messages are stored.
 */
- (void)testStoreBannerPendingMessage {
    self.inAppMessaging.pendingMessageID = self.bannerMessage.identifier;

    XCTAssertEqualObjects(self.inAppMessaging.pendingMessageID, self.bannerMessage.identifier);
}

/**
 * Test that non-banner messages are not stored.
 */
- (void)testStoreNonBannerPendingMessage {
    self.inAppMessaging.pendingMessageID = self.nonBannerMessage.identifier;
    XCTAssertNil(self.inAppMessaging.pendingMessageID);
}

/**
 * Test notification response that contains an in-app message clears the pending message.
 */
- (void)testHandleNotificationResponse {
    XCTAssertNil(self.inAppMessaging.pendingMessageID);

    NSString *messageID = [UALegacyInAppMessage messageWithPayload:self.payload].identifier;
    self.inAppMessaging.pendingMessageID = messageID;
    XCTAssertNotNil(self.inAppMessaging.pendingMessageID);

    NSDictionary *notification = @{
                                   @"_": @"send ID",
                                   @"aps": self.aps,
                                   @"com.urbanairship.in_app": self.payload
                                   };

    UANotificationResponse *response = [UANotificationResponse notificationResponseWithNotificationInfo:notification
                                                                                       actionIdentifier:UANotificationDefaultActionIdentifier
                                                                                           responseText:nil];

    [[self.mockAnalytics expect] addEvent:[OCMArg any]];

    [[[self.mockInAppMessageManager stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(NSArray<UASchedule *> *schedules) = (__bridge void(^)(NSArray<UASchedule *> *))arg;
        UASchedule *dummySchedule = [UASchedule scheduleWithIdentifier:@"foo" info:[UAScheduleInfo new]];
        completionHandler(@[dummySchedule]);
    }] getSchedulesWithMessageID:[OCMArg any] completionHandler:[OCMArg any]];

    [[self.mockInAppMessageManager expect] cancelMessageWithID:messageID];
    [self.inAppMessaging handleNotificationResponse:response];

    [self. mockAnalytics verify];
    XCTAssertNil(self.inAppMessaging.pendingMessageID);
}

/**
 * Test notification response no-ops when it does not contain an in-app message.
 */
- (void)testHandleNotificationResponseNoInApp {
    XCTAssertNil(self.inAppMessaging.pendingMessageID);

    self.inAppMessaging.pendingMessageID = [UALegacyInAppMessage messageWithPayload:self.payload].identifier;
    XCTAssertNotNil(self.inAppMessaging.pendingMessageID);

    NSDictionary *notification = @{
                                   @"_": @"send ID",
                                   @"aps": self.aps
                                   };

    UANotificationResponse *response = [UANotificationResponse notificationResponseWithNotificationInfo:notification
                                                                                       actionIdentifier:UANotificationDefaultActionIdentifier
                                                                                           responseText:nil];

    [[self.mockAnalytics reject] addEvent:[OCMArg any]];
    [[self.mockInAppMessageManager reject] cancelMessageWithID:[OCMArg any]];
    [self.inAppMessaging handleNotificationResponse:response];

    [self.mockAnalytics verify];
    XCTAssertNotNil(self.inAppMessaging.pendingMessageID);
}

/**
 * Test notification response no-ops when the response's in-app message does
 * not match the pending in-app message.
 */
- (void)testHandleNotificationResponseDifferentPendingMessage {
    XCTAssertNil(self.inAppMessaging.pendingMessageID);

    self.inAppMessaging.pendingMessageID = [UALegacyInAppMessage messageWithPayload:self.payload].identifier;
    XCTAssertNotNil(self.inAppMessaging.pendingMessageID);

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
    [[self.mockInAppMessageManager reject] cancelMessageWithID:[OCMArg any]];
    [self.inAppMessaging handleNotificationResponse:response];

    [self.mockAnalytics verify];
    XCTAssertNotNil(self.inAppMessaging.pendingMessageID);
}

/**
 * Test remote notifications that contains an in-app message saves it as a pending
 * message and schedules it.
 */
- (void)testHandleRemoteNotification {
    XCTAssertNil(self.inAppMessaging.pendingMessageID);

    NSDictionary *notification = @{
                                   @"_": @"send ID",
                                   @"aps": self.aps,
                                   @"com.urbanairship.in_app": self.payload
                                   };

    UANotificationResponse *response = [UANotificationResponse notificationResponseWithNotificationInfo:notification
                                                                                       actionIdentifier:UANotificationDefaultActionIdentifier
                                                                                           responseText:nil];

    [[self.mockInAppMessageManager expect] scheduleMessageWithScheduleInfo:[OCMArg isKindOfClass:[UAInAppMessageScheduleInfo class]] completionHandler:[OCMArg any]];

    [self.inAppMessaging handleRemoteNotification:response.notificationContent];
    XCTAssertNotNil(self.inAppMessaging.pendingMessageID);

    [self.mockInAppMessageManager verify];
}

/**
 * Test handling a remote notification no-ops when it does not contain an in-app message.
 */
- (void)testHandleRemoteNotificationNoInApp {
    XCTAssertNil(self.inAppMessaging.pendingMessageID);

    NSDictionary *notification = @{
                                   @"_": @"send ID",
                                   @"aps": self.aps
                                   };

    UANotificationResponse *response = [UANotificationResponse notificationResponseWithNotificationInfo:notification
                                                                                       actionIdentifier:UANotificationDefaultActionIdentifier
                                                                                           responseText:nil];

    [self.inAppMessaging handleRemoteNotification:response.notificationContent];
    XCTAssertNil(self.inAppMessaging.pendingMessageID);
}

/**
 * Test remote notifications that contains an in-app message and a message center
 * message appends an inbox action to the in-app message.
 */
- (void)testHandleRemoteNotificationWithMCRAP {
    NSDictionary *notification = @{
                                   @"_": @"send ID",
                                   @"_uamid": @"some message ID",
                                   @"aps": self.aps,
                                   @"com.urbanairship.in_app": self.payload
                                   };

    UANotificationResponse *response = [UANotificationResponse notificationResponseWithNotificationInfo:notification
                                                                                       actionIdentifier:UANotificationDefaultActionIdentifier
                                                                                           responseText:nil];

    [[[self.mockInAppMessageManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        UAInAppMessageScheduleInfo *info = (__bridge UAInAppMessageScheduleInfo *)arg;
        UAInAppMessageBannerDisplayContent *displayContent = (UAInAppMessageBannerDisplayContent *)info.message.displayContent;
        BOOL containsOpenInboxAction = displayContent.actions[kUADisplayInboxActionDefaultRegistryName] || displayContent.actions[kUADisplayInboxActionDefaultRegistryAlias];
        XCTAssertTrue(containsOpenInboxAction);
    }] scheduleMessageWithScheduleInfo:[OCMArg isKindOfClass:[UAInAppMessageScheduleInfo class]] completionHandler:[OCMArg any]];

    [self.inAppMessaging handleRemoteNotification:response.notificationContent];
    XCTAssertNotNil(self.inAppMessaging.pendingMessageID);

    [self.mockInAppMessageManager verify];
}

/**
 * Test remote notifications that contains an in-app message and a message center
 * does not append an inbox action if one already exists.
 */
- (void)testHandleRemoteNotificationWithMCRAPExistingInboxAction {
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

    [[[self.mockInAppMessageManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        UAInAppMessageScheduleInfo *info = (__bridge UAInAppMessageScheduleInfo *)arg;
        UAInAppMessageBannerDisplayContent *displayContent = (UAInAppMessageBannerDisplayContent *)info.message.displayContent;
        XCTAssertEqualObjects(displayContent.actions[@"^mc"], @"AUTO");
    }] scheduleMessageWithScheduleInfo:[OCMArg isKindOfClass:[UAInAppMessageScheduleInfo class]] completionHandler:[OCMArg any]];

    [self.inAppMessaging handleRemoteNotification:response.notificationContent];
}

@end
