/*
 Copyright 2009-2014 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
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
#import "UAIncomingPushAction.h"
#import "UAPush.h"
#import "UAirship+Internal.h"
#import <OCMock/OCMock.h>

@interface UAIncomingPushActionTest : XCTestCase

@end


@implementation UAIncomingPushActionTest

UAIncomingPushAction *action;
UAActionArguments *arguments;
id mockedPushDelegate;
id mockedAirship;
bool backgroundNotificationEnabled;

- (void)setUp {
    [super setUp];

    backgroundNotificationEnabled = NO;
    arguments = [[UAActionArguments alloc] init];
    arguments.value = @{ @"aps": @{ @"alert": @"sample alert!", @"badge": @2, @"sound": @"cat" }};

    mockedPushDelegate = [OCMockObject niceMockForProtocol:@protocol(UAPushNotificationDelegate)];
    [UAPush shared].pushNotificationDelegate = mockedPushDelegate;

    mockedAirship = [OCMockObject niceMockForClass:[UAirship class]];
    [[[mockedAirship stub] andReturn:mockedAirship] shared];
    [[[mockedAirship stub] andDo:^(NSInvocation *invocation) {
        [invocation setReturnValue:&backgroundNotificationEnabled];
    }] backgroundNotificationEnabled];


    action = [[UAIncomingPushAction alloc] init];
}

- (void)tearDown {
    [UAPush shared].pushNotificationDelegate = nil;
    [mockedPushDelegate stopMocking];
    [mockedAirship stopMocking];

    [super tearDown];
}

/*
 * Tests UAIncomingPushAction only accepts push situations and
 * arguments whose value is an NSDictionary
 */
- (void)testAcceptsArguments {
    UASituation validSituations[3] = {
        UASituationForegroundPush,
        UASituationBackgroundPush,
        UASituationLaunchedFromPush
    };

    arguments.value = nil;

    // Should not accept any of the valid situations because the value is nil
    for (int i = 0; i < 3; i++) {
        arguments.situation = validSituations[i];
        XCTAssertFalse([action acceptsArguments:arguments], @"Should not accept nil value arguments");
    }

    arguments.value = [NSDictionary dictionary];
    arguments.situation = UASituationWebViewInvocation;
    XCTAssertFalse([action acceptsArguments:arguments], @"Should not accept invalid situations");

    // Arguments should be valid
    for (int i = 0; i < 3; i++) {
        arguments.situation = validSituations[i];
        XCTAssertTrue([action acceptsArguments:arguments], @"Should accept valid situation");
    }
}

/**
 * Test running the action with UASituationLaunchedFromPush situation
 */
- (void)testPerformInUASituationLaunchedFromPush {
    __block UAActionResult *runResult;

    arguments.situation = UASituationLaunchedFromPush;

    [[mockedPushDelegate expect] launchedFromNotification:arguments.value];
    [action performWithArguments:arguments withCompletionHandler:^(UAActionResult *result) {
        runResult = result;
    }];

    XCTAssertNoThrow([mockedPushDelegate verify], @"Push delegate launchedFromNotification: should be called");
    XCTAssertNotNil(runResult, @"Incoming push action should still generate an action result");
    XCTAssertNil(runResult.value, @"Incoming push action should default to an empty result");
    XCTAssertEqual((NSUInteger)runResult.fetchResult, UIBackgroundFetchResultNoData, @"Push action should return the delegate's fetch result");

    // Turn on background notifications
    backgroundNotificationEnabled = YES;
    XCTAssertTrue([UAirship shared].backgroundNotificationEnabled, @"Should accept valid situation");

    // Expect the notification and call the block with the delegateResult
    [[mockedPushDelegate expect] launchedFromNotification:arguments.value fetchCompletionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(UIBackgroundFetchResult) = obj;
        completionBlock(UIBackgroundFetchResultNewData);
        return YES;
    }]];

    [action performWithArguments:arguments withCompletionHandler:^(UAActionResult *result) {
        runResult = result;
    }];

    XCTAssertNoThrow([mockedPushDelegate verify], @"Push delegate launchedFromNotification:fetchCompletionHandler: should be called");
    XCTAssertNil(runResult.value, @"Value should always be nil");
    XCTAssertEqual((NSUInteger)runResult.fetchResult, UIBackgroundFetchResultNewData, @"Push action should return the delegate's fetch result");
}


/**
 * Test running the action with UASituationBackgroundPush situation
 */
- (void)testPerformInUASituationBackgroundPush {
    __block UAActionResult *runResult;

    arguments.situation = UASituationBackgroundPush;

    [[mockedPushDelegate expect] receivedBackgroundNotification:arguments.value];
    [action performWithArguments:arguments withCompletionHandler:^(UAActionResult *result) {
        runResult = result;
    }];

    XCTAssertNoThrow([mockedPushDelegate verify], @"Push delegate receivedBackgroundNotification: should be called");
    XCTAssertNotNil(runResult, @"Incoming push action should still generate an action result");
    XCTAssertNil(runResult.value, @"Incoming push action should default to an empty result");
    XCTAssertEqual((NSUInteger)runResult.fetchResult, UIBackgroundFetchResultNoData, @"Push action should return the delegate's fetch result");

    // Turn on background notifications
    backgroundNotificationEnabled = YES;
    XCTAssertTrue([UAirship shared].backgroundNotificationEnabled, @"Should accept valid situation");

    // Expect the notification and call the block with the delegateResult
    [[mockedPushDelegate expect] receivedBackgroundNotification:arguments.value fetchCompletionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(UIBackgroundFetchResult) = obj;
        completionBlock(UIBackgroundFetchResultNewData);
        return YES;
    }]];

    [action performWithArguments:arguments withCompletionHandler:^(UAActionResult *result) {
        runResult = result;
    }];

    XCTAssertNoThrow([mockedPushDelegate verify], @"Push delegate receivedBackgroundNotification:fetchCompletionHandler: should be called");
    XCTAssertNil(runResult.value, @"Value should always be nil");
    XCTAssertEqual((NSUInteger)runResult.fetchResult, UIBackgroundFetchResultNewData, @"Push action should return the delegate's fetch result");
}

/**
 * Test running the action with UASituationForegroundPush situation
 */
- (void)testPerformInUASituationForegroundPush {
    __block UAActionResult *runResult;

    arguments.situation = UASituationForegroundPush;

    [[mockedPushDelegate expect] receivedForegroundNotification:arguments.value];

    [action performWithArguments:arguments withCompletionHandler:^(UAActionResult *result) {
        runResult = result;
    }];

    XCTAssertNoThrow([mockedPushDelegate verify], @"Push delegate receivedForegroundNotification: should be called");
    XCTAssertNotNil(runResult, @"Incoming push action should still generate an action result");
    XCTAssertNil(runResult.value, @"Incoming push action should default to an empty result");
    XCTAssertEqual((NSUInteger)runResult.fetchResult, UIBackgroundFetchResultNoData, @"Push action should return the delegate's fetch result");

    // Turn on background notifications
    backgroundNotificationEnabled = YES;
    XCTAssertTrue([UAirship shared].backgroundNotificationEnabled, @"Should accept valid situation");

    // Expect the notification and call the block with the delegateResult
    [[mockedPushDelegate expect] receivedForegroundNotification:arguments.value fetchCompletionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(UIBackgroundFetchResult) = obj;
        completionBlock(UIBackgroundFetchResultNewData);
        return YES;
    }]];

    [action performWithArguments:arguments withCompletionHandler:^(UAActionResult *result) {
        runResult = result;
    }];

    XCTAssertNoThrow([mockedPushDelegate verify], @"Push delegate receivedForegroundNotification:fetchCompletionHandler: should be called");
    XCTAssertNil(runResult.value, @"Value should always be nil");
    XCTAssertEqual((NSUInteger)runResult.fetchResult, UIBackgroundFetchResultNewData, @"Push action should return the delegate's fetch result");
}


/**
 * Test running the action with UASituationForegroundPush situation notifies
 * the app delegate of an alert, sound, and badge
 */
- (void)testPerformInUASituationForegroundPushNotifyForegroundAlert {
    arguments.situation = UASituationForegroundPush;
    [UAPush shared].autobadgeEnabled = NO;
    
    [[mockedPushDelegate expect] playNotificationSound:@"cat"];
    [[mockedPushDelegate expect] displayNotificationAlert:@"sample alert!"];
    [[mockedPushDelegate expect] handleBadgeUpdate:2];

    [action performWithArguments:arguments withCompletionHandler:^(UAActionResult *result) {}];
    XCTAssertNoThrow([mockedPushDelegate verify], @"Push delegate should notify the delegate of a foreground notification");

    // Enable auto badge and verify handleBadgeUpdate: is not called
    [UAPush shared].autobadgeEnabled = YES;

    [[mockedPushDelegate expect] playNotificationSound:@"cat"];
    [[mockedPushDelegate expect] displayNotificationAlert:@"sample alert!"];
    [[mockedPushDelegate reject] handleBadgeUpdate:2];

    [action performWithArguments:arguments withCompletionHandler:^(UAActionResult *result) {}];
    XCTAssertNoThrow([mockedPushDelegate verify], @"Push delegates handleBadgeUpdate should not be called if autobadge is enabled");


    // Set to an empty notification
    arguments.value = [NSDictionary dictionary];
    [[mockedPushDelegate reject] playNotificationSound:OCMOCK_ANY];
    [[mockedPushDelegate reject] displayNotificationAlert:OCMOCK_ANY];
    [[mockedPushDelegate reject] handleBadgeUpdate:2];

    [action performWithArguments:arguments withCompletionHandler:^(UAActionResult *result) {}];
    XCTAssertNoThrow([mockedPushDelegate verify], @"Push delegates should not be notified of an empty dictionary");
}



@end
