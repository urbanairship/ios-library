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
#import <OCMock/OCMock.h>
#import "UAIncomingRichPushAction.h"
#import "UAPushActionArguments.h"
#import "UAInbox.h"
#import "UAInboxPushHandler.h"
#import "UAInboxMessageList.h"

@interface UAIncomingRichPushActionTest : XCTestCase

@end

@implementation UAIncomingRichPushActionTest

UAIncomingRichPushAction *action;
UAPushActionArguments *arguments;
id mockInbox;
id mockPushHandler;
id mockPushHandlerDelegate;
id mockMessageList;

- (void)setUp {
    [super setUp];

    action = [[UAIncomingRichPushAction alloc] init];

    arguments = [[UAPushActionArguments alloc] init];
    arguments.value = @"rich-push-id";
    arguments.payload = @{@"aps": @{}, @"_uamid":@"rich-push-id"};

    mockPushHandler = [OCMockObject niceMockForClass:[UAInboxPushHandler class]];
    mockPushHandlerDelegate = [OCMockObject niceMockForProtocol:@protocol(UAInboxPushHandlerDelegate)];
    mockMessageList = [OCMockObject niceMockForClass:[UAInboxMessageList class]];
    mockInbox = [OCMockObject mockForClass:[UAInbox class]];

    [[[mockInbox stub] andReturn:mockInbox] shared];
    [[[mockInbox stub] andReturn:mockMessageList] messageList];
    [[[mockInbox stub] andReturn:mockPushHandler] pushHandler];

    [[[mockPushHandler stub] andReturn:mockPushHandlerDelegate] delegate];
}

- (void)tearDown {
    [mockInbox stopMocking];
    [mockPushHandler stopMocking];
    [mockMessageList stopMocking];
    [mockPushHandlerDelegate stopMocking];

    [super tearDown];
}

/**
 * Test accepts valid arguments
 */
- (void)testAcceptsArguments {
    arguments.situation = UASituationForegroundPush;
    XCTAssertTrue([action acceptsArguments:arguments], @"action should accepts valid arguments in UASituationForegroundPush situation");

    arguments.situation = UASituationLaunchedFromPush;
    XCTAssertTrue([action acceptsArguments:arguments], @"action should accepts valid arguments in UASituationLaunchedFromPush situation");

    arguments.value = @[@"RAP-id"];
    XCTAssertTrue([action acceptsArguments:arguments], @"action should accepts an array that contains a RAP id");

    arguments.situation = UASituationBackgroundPush;
    XCTAssertFalse([action acceptsArguments:arguments], @"action should not accept argument in UASituationBackgroundPush situation");

    arguments.situation = UASituationWebViewInvocation;
    XCTAssertFalse([action acceptsArguments:arguments], @"action should not accept argument in an invalid situation");

    arguments.situation = UASituationForegroundPush;
    arguments.value = @3;
    XCTAssertFalse([action acceptsArguments:arguments], @"action should not accept argument with an invalid RAP id");

    UAActionArguments *invalidArgs = [UAActionArguments argumentsWithValue:@"valid-id" withSituation:UASituationForegroundPush];
    XCTAssertFalse([action acceptsArguments:invalidArgs], @"action should not accept arguments that are not UAPushActionArguments");
}

/**
 * Test perform in UASituationForegroundPush situation
 */
- (void)testPerformInUASituationForegroundPush {
    arguments.situation = UASituationForegroundPush;
    __block UAActionResult *actionResult = nil;

    // Should retrive new message list
    [[mockMessageList expect] retrieveMessageListWithDelegate:mockPushHandler];

    // Should notify the RAP notification arrived
    [[mockPushHandlerDelegate expect] richPushNotificationArrived:arguments.payload];

    [action performWithArguments:arguments withCompletionHandler:^(UAActionResult *result) {
        actionResult = result;
    }];

    XCTAssertNotNil(actionResult, @"perform did not call the completion handler");
    XCTAssertEqualObjects(actionResult.value, @"rich-push-id", @"Results value should be the RAP id");
    XCTAssertNoThrow([mockMessageList verify], @"message list should retreive new RAPs");
    XCTAssertNoThrow([mockPushHandlerDelegate verify], @"handler delegate should be notified of a RAP notification");
}

/**
 * Test perform in UASituationLaunchedFromPush situation
 */
- (void)testPerformInUASituationLaunchedFromPush {
    arguments.situation = UASituationLaunchedFromPush;
    __block UAActionResult *actionResult = nil;

    // Should retrive new message list
    [[mockMessageList expect] retrieveMessageListWithDelegate:mockPushHandler];

    // Should notify the delegate that it was launched with a RAP notification
    [[mockPushHandlerDelegate expect] applicationLaunchedWithRichPushNotification:arguments.payload];

    // Should tell the handler there is a launch message
    [[mockPushHandler expect] setHasLaunchMessage:YES];

    [action performWithArguments:arguments withCompletionHandler:^(UAActionResult *result) {
        actionResult = result;
    }];

    XCTAssertNotNil(actionResult, @"perform did not call the completion handler");
    XCTAssertEqualObjects(actionResult.value, @"rich-push-id", @"Results value should be the RAP id");
    XCTAssertNoThrow([mockMessageList verify], @"message list should retreive new RAPs");
    XCTAssertNoThrow([mockPushHandlerDelegate verify], @"handler delegate should be notified of a RAP notification");
    XCTAssertNoThrow([mockPushHandler verify], @"handler should set hasLaunchMessage");
}


@end
