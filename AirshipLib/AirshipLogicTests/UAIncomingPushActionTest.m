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
#import "UAIncomingPushAction+Internal.h"
#import "UAPush.h"
#import "UAirship+Internal.h"
#import <OCMock/OCMock.h>
#import "UAActionArguments+Internal.h"
#import "UAPreferenceDataStore+Internal.h"

@interface UAIncomingPushActionTest : XCTestCase

@property (nonatomic, strong) UAIncomingPushAction *action;
@property (nonatomic, strong) UAActionArguments *arguments;
@property (nonatomic, strong) id mockedPushDelegate;
@property (nonatomic, strong) id mockedAirship;
@property (nonatomic, strong) id mockPush;

@property bool backgroundNotificationEnabled;

@end

@implementation UAIncomingPushActionTest

- (void)setUp {
    [super setUp];

    self.backgroundNotificationEnabled = NO;
    self.arguments = [[UAActionArguments alloc] init];
    self.arguments.value = @{ @"aps": @{ @"alert": @"sample alert!", @"badge": @2, @"sound": @"cat" }};

    self.mockedPushDelegate = [OCMockObject niceMockForProtocol:@protocol(UAPushNotificationDelegate)];

    self.mockPush = [OCMockObject niceMockForClass:[UAPush class]];
    [[[self.mockPush stub] andReturn:self.mockedPushDelegate] pushNotificationDelegate];

    self.mockedAirship = [OCMockObject niceMockForClass:[UAirship class]];
    [[[self.mockedAirship stub] andReturn:self.mockedAirship] shared];
    [[[self.mockedAirship stub] andReturn:self.mockPush] push];

    [[[self.mockedAirship stub] andDo:^(NSInvocation *invocation) {
        [invocation setReturnValue:&_backgroundNotificationEnabled];
    }] remoteNotificationBackgroundModeEnabled];


    self.action = [[UAIncomingPushAction alloc] init];
}

- (void)tearDown {
    [self.mockedPushDelegate stopMocking];
    [self.mockedAirship stopMocking];
    [self.mockPush stopMocking];

    [super tearDown];
}

/*
 * Tests UAIncomingPushAction only accepts push situations and
 * arguments whose value is an NSDictionary
 */
- (void)testAcceptsArguments {
    UASituation validSituations[5] = {
        UASituationForegroundPush,
        UASituationBackgroundPush,
        UASituationLaunchedFromPush,
        UASituationForegroundInteractiveButton,
        UASituationBackgroundInteractiveButton
    };

    self.arguments.value = nil;

    // Should not accept any of the valid situations because the value is nil
    for (int i = 0; i < 5; i++) {
        self.arguments.situation = validSituations[i];
        XCTAssertFalse([self.action acceptsArguments:self.arguments], @"Should not accept nil value arguments");
    }

    self.arguments.value = [NSDictionary dictionary];
    self.arguments.situation = UASituationWebViewInvocation;
    XCTAssertFalse([self.action acceptsArguments:self.arguments], @"Should not accept invalid situations");

    // Arguments should be valid
    for (int i = 0; i < 5; i++) {
        self.arguments.situation = validSituations[i];
        XCTAssertTrue([self.action acceptsArguments:self.arguments], @"Should accept valid situation");
    }
}

/**
 * Test running the action with UASituationLaunchedFromPush situation
 */
- (void)testPerformInUASituationLaunchedFromPush {
    __block UAActionResult *runResult;

    self.arguments.situation = UASituationLaunchedFromPush;

    __block UANotificationResponse *response = [UANotificationResponse notificationResponseWithNotificationInfo:self.arguments.value
                                                                                               actionIdentifier:UANotificationDefaultActionIdentifier];

    [[self.mockedPushDelegate expect] receivedNotificationResponse:[OCMArg checkWithBlock:^BOOL(UANotificationResponse *obj) {

        if (obj.actionIdentifier != response.actionIdentifier) {
            return NO;
        }
        if (![obj.notificationContent.notificationInfo
              isEqualToDictionary:response.notificationContent.notificationInfo]) {
            return NO;
        }

        return YES;
    }] completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)() = obj;
        completionBlock([UAActionResult emptyResult]);
        return YES;
    }]];

    [self.action performWithArguments:self.arguments completionHandler:^(UAActionResult *result) {
        runResult = result;
    }];

    XCTAssertNoThrow([self.mockedPushDelegate verify], @"Push delegate receivedNotificationResponse:completionHandler should be called");
    XCTAssertNotNil(runResult, @"Incoming push action should generate an empty action result");
    XCTAssertNil(runResult.value, @"Incoming push action should default to an empty result");
    XCTAssertEqual((NSUInteger)runResult.fetchResult, UIBackgroundFetchResultNoData, @"Push action should return the delegate's fetch result");

    // Turn on background notifications
    self.backgroundNotificationEnabled = YES;
    XCTAssertTrue([UAirship shared].remoteNotificationBackgroundModeEnabled, @"Should accept valid situation");
}


/**
 * Test running the action with UASituationBackgroundPush situation
 */
- (void)testPerformInUASituationBackgroundPush {
    __block UAActionResult *runResult;

    self.arguments.situation = UASituationBackgroundPush;

    // Turn on background notifications
    self.backgroundNotificationEnabled = YES;

    // Expect the notification and call the block with the delegateResult
    XCTAssertTrue([UAirship shared].remoteNotificationBackgroundModeEnabled, @"Should accept valid situation");

    // Create UANotificationContent with arguments metadata to allow for easier parsing
    __block UANotificationContent *notificationContent = [UANotificationContent notificationWithNotificationInfo:self.arguments.value];

    [[self.mockedPushDelegate expect] receivedBackgroundNotification:[OCMArg checkWithBlock:^BOOL(UANotificationContent *obj) {

        if (![obj.notificationInfo isEqualToDictionary:notificationContent.notificationInfo]) {
            return NO;
        }

        return YES;
    }] completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(UIBackgroundFetchResult) = obj;
        completionBlock(UIBackgroundFetchResultNewData);
        return YES;
    }]];

    [self.action performWithArguments:self.arguments completionHandler:^(UAActionResult *result) {
        runResult = result;
    }];

    XCTAssertNoThrow([self.mockedPushDelegate verify], @"Push delegate receivedBackgroundNotification:fetchCompletionHandler: should be called");
    XCTAssertNil(runResult.value, @"Value should always be nil");
    XCTAssertEqual((NSUInteger)runResult.fetchResult, UIBackgroundFetchResultNewData, @"Push action should return the delegate's fetch result");
}

/**
 * Test running the action with UASituationForegroundPush situation
 */
- (void)testPerformInUASituationForegroundPush {
    __block UAActionResult *runResult;

    self.arguments.situation = UASituationForegroundPush;

    // Create UANotificationContent with arguments metadata to allow for easier parsing
    __block UANotificationContent *notificationContent = [UANotificationContent notificationWithNotificationInfo:self.arguments.value];

    [[self.mockedPushDelegate expect] receivedForegroundNotification:[OCMArg checkWithBlock:^BOOL(UANotificationContent *obj) {
        if (![obj.notificationInfo isEqualToDictionary:notificationContent.notificationInfo]) {
            return NO;
        }

        return YES;
    }] completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(UIBackgroundFetchResult) = obj;
        completionBlock(UIBackgroundFetchResultNewData);
        return YES;
    }]];

    [self.action performWithArguments:self.arguments completionHandler:^(UAActionResult *result) {
        runResult = result;
    }];

    XCTAssertNoThrow([self.mockedPushDelegate verify], @"Push delegate receivedForegroundNotification:fetchCompletionHandler: should be called");
    XCTAssertNil(runResult.value, @"Value should always be nil");
    XCTAssertEqual((NSUInteger)runResult.fetchResult, UIBackgroundFetchResultNewData, @"Push action should return the delegate's fetch result");
}

/**
 * Test running the action with UASituationForegroundInteractiveButton situation notifies
 * the app delegate of the event.
 */
- (void)testForegroundUserNotificationAction {
    __block UAActionResult *runResult;

    self.arguments.situation = UASituationForegroundInteractiveButton;
    self.arguments.metadata = @{UAActionMetadataUserNotificationActionIDKey: @"action ID"};

    __block UANotificationResponse *response = [UANotificationResponse notificationResponseWithNotificationInfo:self.arguments.value
                                                                                               actionIdentifier:@"action ID"];
    // Expect the delegate to be called. Use a checkWithBlock to call the completion handler.
    [[self.mockedPushDelegate expect] receivedNotificationResponse:[OCMArg checkWithBlock:^BOOL(UANotificationResponse *obj) {

        if (obj.actionIdentifier != response.actionIdentifier) {
            return NO;
        }
        if (![obj.notificationContent.notificationInfo
              isEqualToDictionary:response.notificationContent.notificationInfo]) {
            return NO;
        }

        return YES;
    }] completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)() = obj;
        completionBlock();
        return YES;
    }]];

    [self.action performWithArguments:self.arguments completionHandler:^(UAActionResult *result) {
        runResult = result;
    }];

    XCTAssertNoThrow([self.mockedPushDelegate verify], @"Push delegate launchedFromNotification:actionIdentifier:completionHandler: should be called");
    XCTAssertNotNil(runResult, @"Incoming push action should generate an action result");
    XCTAssertNil(runResult.value, @"Incoming push action should default to an empty result");
    XCTAssertEqual((NSUInteger)runResult.fetchResult, UIBackgroundFetchResultNoData, @"Push action should return the delegate's fetch result");
}

/**
 * Test running the action with UASituationBackgroundInteractiveButton situation notifies
 * the app delegate of the event.
 */
- (void)testBackgroundUserNotificationAction {
    __block UAActionResult *runResult;

    self.arguments.situation = UASituationBackgroundInteractiveButton;
    self.arguments.metadata = @{UAActionMetadataUserNotificationActionIDKey: @"action ID"};

    __block UANotificationResponse *response = [UANotificationResponse notificationResponseWithNotificationInfo:self.arguments.value
                                                                                               actionIdentifier:@"action ID"];

    // Expect the delegate to be called. Use a checkWithBlock to call the completion handler.
    [[self.mockedPushDelegate expect] receivedNotificationResponse:[OCMArg checkWithBlock:^BOOL(UANotificationResponse *obj) {

        if (obj.actionIdentifier != response.actionIdentifier) {
            return NO;
        }
        if (![obj.notificationContent.notificationInfo
              isEqualToDictionary:response.notificationContent.notificationInfo]) {
            return NO;
        }

        return YES;
    }] completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)() = obj;
        completionBlock();
        return YES;
    }]];

    [self.action performWithArguments:self.arguments completionHandler:^(UAActionResult *result) {
        runResult = result;
    }];

    XCTAssertNoThrow([self.mockedPushDelegate verify], @"Push delegate receivedBackgroundNotification:actionIdentifier:completionHandler: should be called");
    XCTAssertNotNil(runResult, @"Incoming push action should generate an action result");
    XCTAssertNil(runResult.value, @"Incoming push action should default to an empty result");
    XCTAssertEqual((NSUInteger)runResult.fetchResult, UIBackgroundFetchResultNoData, @"Push action should return the delegate's fetch result");
}

@end
