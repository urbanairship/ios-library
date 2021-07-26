/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UALegacyInAppMessaging+Internal.h"
#import "UAirship+Internal.h"
#import "UAAnalytics.h"
#import "UAActionRegistry.h"
#import "UAInAppMessageBannerDisplayContent.h"
#import "UASchedule+Internal.h"
#import "UAInAppMessage+Internal.h"
#import "UAInAppAutomation.h"
#import "UALegacyInAppMessage.h"

@import AirshipCore;

@interface UALegacyInAppMessagingTest : UAAirshipBaseTest
@property(nonatomic, strong) id mockAnalytics;
@property(nonatomic, strong) id mockInAppAutomation;

@property(nonatomic, strong) UALegacyInAppMessage *bannerMessage;
@property(nonatomic, strong) UALegacyInAppMessage *nonBannerMessage;
@property(nonatomic, strong) UALegacyInAppMessaging *inAppMessaging;
@property(nonatomic, copy) NSDictionary *payload;
@property(nonatomic, copy) NSDictionary *aps;

@end

@implementation UALegacyInAppMessagingTest

- (void)setUp {
    [super setUp];

    self.mockAnalytics = [self mockForClass:[UAAnalytics class]];
    self.mockInAppAutomation = [self mockForClass:[UAInAppAutomation class]];

    self.inAppMessaging = [UALegacyInAppMessaging inAppMessagingWithAnalytics:self.mockAnalytics
                                                                    dataStore:self.dataStore
                                                              inAppAutomation:self.mockInAppAutomation];

    self.bannerMessage = [UALegacyInAppMessage message];
    self.bannerMessage.identifier = @"identifier";
    self.bannerMessage.alert = @"whatever";
    self.bannerMessage.displayType = UALegacyInAppMessageDisplayTypeBanner;
    self.bannerMessage.expiry = [NSDate dateWithTimeIntervalSinceNow:10000];

    self.nonBannerMessage.alert = @"blah";

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

    self.aps = @{ @"alert": @"sample alert",
                   @"badge": @2,
                   @"sound": @"cat"
                };
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

    id unNotification = [self mockForClass:[UNNotification class]];
    id request = [self mockForClass:[UNNotificationRequest class]];
    id content = [self mockForClass:[UNNotificationContent class]];
    id response = [self mockForClass:[UNNotificationResponse class]];
    [[[response stub] andReturn:unNotification] notification];
    [[[response stub] andReturn:UNNotificationDefaultActionIdentifier] actionIdentifier];
    [[[unNotification stub] andReturn:request] request];
    [[[request stub] andReturn:content] content];
    [[[content stub] andReturn:notification] userInfo];

    [[self.mockAnalytics expect] addEvent:[OCMArg any]];

    [[[self.mockInAppAutomation expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(BOOL) = (__bridge void(^)(BOOL))arg;
        completionHandler(YES);
    }] cancelScheduleWithID:messageID completionHandler:OCMOCK_ANY];

    XCTestExpectation *testExpectation = [self expectationWithDescription:@"completion handler called"];
    [((NSObject<UAPushableComponent> *) self.inAppMessaging) receivedNotificationResponse:response completionHandler:^{
        [testExpectation fulfill];
    }];

    [self waitForTestExpectations];
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

    id unNotification = [self mockForClass:[UNNotification class]];
    id request = [self mockForClass:[UNNotificationRequest class]];
    id content = [self mockForClass:[UNNotificationContent class]];
    id response = [self mockForClass:[UNNotificationResponse class]];
    [[[response stub] andReturn:unNotification] notification];
    [[[response stub] andReturn:UNNotificationDefaultActionIdentifier] actionIdentifier];
    [[[unNotification stub] andReturn:request] request];
    [[[request stub] andReturn:content] content];
    [[[content stub] andReturn:notification] userInfo];

    [[self.mockAnalytics reject] addEvent:[OCMArg any]];
    [[self.mockInAppAutomation reject] cancelScheduleWithID:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *testExpectation = [self expectationWithDescription:@"completion handler called"];
    [((NSObject<UAPushableComponent> *) self.inAppMessaging) receivedNotificationResponse:response completionHandler:^{
        [testExpectation fulfill];
    }];

    [self waitForTestExpectations];
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

    id unNotification = [self mockForClass:[UNNotification class]];
    id request = [self mockForClass:[UNNotificationRequest class]];
    id content = [self mockForClass:[UNNotificationContent class]];
    id response = [self mockForClass:[UNNotificationResponse class]];
    [[[response stub] andReturn:unNotification] notification];
    [[[response stub] andReturn:UNNotificationDefaultActionIdentifier] actionIdentifier];
    [[[unNotification stub] andReturn:request] request];
    [[[request stub] andReturn:content] content];
    [[[content stub] andReturn:notification] userInfo];


    [[self.mockAnalytics reject] addEvent:[OCMArg any]];
    [[self.mockInAppAutomation reject] cancelScheduleWithID:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *testExpectation = [self expectationWithDescription:@"completion handler called"];
    [((NSObject<UAPushableComponent> *) self.inAppMessaging) receivedNotificationResponse:response completionHandler:^{
        [testExpectation fulfill];
    }];
    [self waitForTestExpectations];

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

    [[[self.mockInAppAutomation expect] andDo:^(NSInvocation *invocation) {
        void *completionHandlerArg;
        [invocation getArgument:&completionHandlerArg atIndex:3];
        void (^completionHandler)(BOOL) = (__bridge void(^)(BOOL))completionHandlerArg;
        completionHandler(YES);
    }] schedule:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *testExpectation = [self expectationWithDescription:@"completion handler called"];
    [((NSObject<UAPushableComponent> *) self.inAppMessaging) receivedRemoteNotification:notification completionHandler:^(UIBackgroundFetchResult fetchResult) {
        XCTAssertEqual(UIBackgroundFetchResultNoData, fetchResult);
        [testExpectation fulfill];
    }];
    [self waitForTestExpectations];

    XCTAssertNotNil(self.inAppMessaging.pendingMessageID);
    [self.mockInAppAutomation verify];
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

    XCTestExpectation *testExpectation = [self expectationWithDescription:@"completion handler called"];
    [((NSObject<UAPushableComponent> *) self.inAppMessaging) receivedRemoteNotification:notification completionHandler:^(UIBackgroundFetchResult fetchResult) {
        XCTAssertEqual(UIBackgroundFetchResultNoData, fetchResult);
        [testExpectation fulfill];
    }];
    [self waitForTestExpectations];

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

    [[[self.mockInAppAutomation expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        UASchedule *schedule = (__bridge UASchedule *)arg;
        UAInAppMessage *message = (UAInAppMessage *)schedule.data;

        UAInAppMessageBannerDisplayContent *displayContent = (UAInAppMessageBannerDisplayContent *)message.displayContent;
        XCTAssertTrue(displayContent.actions[@"_uamid"]);

        void *completionHandlerArg;
        [invocation getArgument:&completionHandlerArg atIndex:3];
        void (^completionHandler)(BOOL) = (__bridge void(^)(BOOL))completionHandlerArg;
        completionHandler(YES);
    }] schedule:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *testExpectation = [self expectationWithDescription:@"completion handler called"];
    [((NSObject<UAPushableComponent> *) self.inAppMessaging) receivedRemoteNotification:notification completionHandler:^(UIBackgroundFetchResult fetchResult) {
        XCTAssertEqual(UIBackgroundFetchResultNoData, fetchResult);
        [testExpectation fulfill];
    }];
    [self waitForTestExpectations];

    XCTAssertNotNil(self.inAppMessaging.pendingMessageID);

    [self.mockInAppAutomation verify];
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

    [[[self.mockInAppAutomation expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        UASchedule *schedule = (__bridge UASchedule *)arg;
        UAInAppMessage *message = (UAInAppMessage *)schedule.data;
        UAInAppMessageBannerDisplayContent *displayContent = (UAInAppMessageBannerDisplayContent *)message.displayContent;
        XCTAssertEqualObjects(displayContent.actions[@"^mc"], @"AUTO");

        void *completionHandlerArg;
        [invocation getArgument:&completionHandlerArg atIndex:3];
        void (^completionHandler)(BOOL) = (__bridge void(^)(BOOL))completionHandlerArg;
        completionHandler(YES);
    }] schedule:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *testExpectation = [self expectationWithDescription:@"completion handler called"];
    [((NSObject<UAPushableComponent> *) self.inAppMessaging) receivedRemoteNotification:notification completionHandler:^(UIBackgroundFetchResult fetchResult) {
        XCTAssertEqual(UIBackgroundFetchResultNoData, fetchResult);
        [testExpectation fulfill];
    }];
    [self waitForTestExpectations];

    [self.mockInAppAutomation verify];

}

/**
 * Test the source is set on the in-app messages.
 */
- (void)testLegacySource {
    NSDictionary *notification = @{
                                   @"_": @"send ID",
                                   @"_uamid": @"some message ID",
                                   @"aps": self.aps,
                                   @"com.urbanairship.in_app": self.payload
                                   };

    [[[self.mockInAppAutomation expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        UASchedule *schedule = (__bridge UASchedule *)arg;
        UAInAppMessage *message = (UAInAppMessage *)schedule.data;
        XCTAssertEqual(message.source, UAInAppMessageSourceLegacyPush);

        void *completionHandlerArg;
        [invocation getArgument:&completionHandlerArg atIndex:3];
        void (^completionHandler)(BOOL) = (__bridge void(^)(BOOL))completionHandlerArg;
        completionHandler(YES);
    }] schedule:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *testExpectation = [self expectationWithDescription:@"completion handler called"];
    [((NSObject<UAPushableComponent> *) self.inAppMessaging)
     receivedRemoteNotification:notification completionHandler:^(UIBackgroundFetchResult fetchResult) {
        XCTAssertEqual(UIBackgroundFetchResultNoData, fetchResult);
        [testExpectation fulfill];
    }];
    [self waitForTestExpectations];

    [self.mockInAppAutomation verify];
}

@end
