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
#import "UAOverlayInboxMessageAction.h"
#import "UAActionArguments+Internal.h"
#import "UAirship.h"
#import "UAInbox.h"
#import "UAInboxMessage.h"
#import "UAInboxMessageList.h"
#import "UALandingPageOverlayController.h"

@interface UAOverlayInboxMessageActionTest : XCTestCase

@property (nonatomic, strong) UAOverlayInboxMessageAction *action;
@property (nonatomic, strong) UAActionArguments *arguments;
@property (nonatomic, strong) id mockInbox;
@property (nonatomic, strong) id mockMessageList;
@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) id mockLandingPageOverlayController;

@end

@implementation UAOverlayInboxMessageActionTest

- (void)setUp {
    [super setUp];

    self.action = [[UAOverlayInboxMessageAction alloc] init];

    self.mockAirship = [OCMockObject mockForClass:[UAirship class]];
    [[[self.mockAirship stub] andReturn:self.mockAirship] shared];

    self.mockInbox = [OCMockObject mockForClass:[UAInbox class]];
    [[[self.mockAirship stub] andReturn:self.mockInbox] inbox];

    self.mockMessageList = [OCMockObject niceMockForClass:[UAInboxMessageList class]];
    [[[self.mockInbox stub] andReturn:self.mockMessageList] messageList];

    self.mockLandingPageOverlayController = [OCMockObject niceMockForClass:[UALandingPageOverlayController class]];
}

- (void)tearDown {
    [self.mockAirship stopMocking];
    [self.mockInbox stopMocking];
    [self.mockMessageList stopMocking];
    [self.mockLandingPageOverlayController stopMocking];
    
    [super tearDown];
}

/**
 * Test the action accepts message ID in foreground situations.
 */
- (void)testAcceptsArgumentsMessageID {
    UASituation validSituations[6] = {
        UASituationForegroundInteractiveButton,
        UASituationLaunchedFromPush,
        UASituationManualInvocation,
        UASituationWebViewInvocation,
        UASituationForegroundPush,
        UASituationAutomation
    };

    UASituation rejectedSituations[2] = {
        UASituationBackgroundPush,
        UASituationBackgroundInteractiveButton,
    };

    UAActionArguments *arguments = [[UAActionArguments alloc] init];
    arguments.value = @"the_message_id";

    for (int i = 0; i < 6; i++) {
        arguments.situation = validSituations[i];
        XCTAssertTrue([self.action acceptsArguments:arguments], @"action should accept situation %zd", validSituations[i]);
    }

    for (int i = 0; i < 2; i++) {
        arguments.situation = rejectedSituations[i];
        XCTAssertFalse([self.action acceptsArguments:arguments], @"action should reject situation %zd", rejectedSituations[i]);
    }
}

/**
 * Test the action accepts "auto" placeholder when it contains either inbox
 * message metadata or push notification metadata.
 */
- (void)testAcceptsArgumentMessageIDPlaceHolder {
    UASituation validSituations[6] = {
        UASituationForegroundInteractiveButton,
        UASituationLaunchedFromPush,
        UASituationManualInvocation,
        UASituationWebViewInvocation,
        UASituationForegroundPush,
        UASituationAutomation
    };

    UAActionArguments *arguments = [[UAActionArguments alloc] init];
    arguments.value = @"auto";

    // Verify it rejects the valid situations if no metadata is present
    for (int i = 0; i < 6; i++) {
        arguments.situation = validSituations[i];
        XCTAssertFalse([self.action acceptsArguments:arguments], @"action should reject situation %zd", validSituations[i]);
    }

    // Verify it accepts the message place holder if we have a inbox message metadata
    arguments.metadata = @{UAActionMetadataInboxMessageKey: [OCMockObject niceMockForClass:[UAInboxMessage class]]};
    for (int i = 0; i < 2; i++) {
        arguments.situation = validSituations[i];
        XCTAssertTrue([self.action acceptsArguments:arguments], @"action should accept situation %zd", validSituations[i]);
    }

    // Verify it accepts the message place holder if we have a push message metadata
    arguments.metadata = @{UAActionMetadataPushPayloadKey: @{}};
    for (int i = 0; i < 2; i++) {
        arguments.situation = validSituations[i];
        XCTAssertTrue([self.action acceptsArguments:arguments], @"action should accept situation %zd", validSituations[i]);
    }
}

/**
 * Test perform with a message ID thats available in the message list is displayed
 * in a landing page controller.
 */
- (void)testPerform {
    __block BOOL actionPerformed;

    UAActionArguments *arguments = [UAActionArguments argumentsWithValue:@"MCRAP" withSituation:UASituationManualInvocation];

    UAInboxMessage *message = [OCMockObject niceMockForClass:[UAInboxMessage class]];
    [[[self.mockMessageList stub] andReturn:message] messageForID:@"MCRAP"];

    [[self.mockLandingPageOverlayController expect] showMessage:message];

    [self.action performWithArguments:arguments completionHandler:^(UAActionResult *result) {
        actionPerformed = YES;
        XCTAssertNil(result.value);
        XCTAssertNil(result.error);
    }];

    XCTAssertTrue(actionPerformed);
    [self.mockLandingPageOverlayController verify];
}


/**
 * Test perform with a message ID that is available after a message refresh is displayed
 * in a landing page controller.
 */
- (void)testPerformMessageListUpdate {
    __block BOOL actionPerformed;

    UAActionArguments *arguments = [UAActionArguments argumentsWithValue:@"MCRAP" withSituation:UASituationManualInvocation];

    __block UAInboxMessage *message = [OCMockObject niceMockForClass:[UAInboxMessage class]];
    [[self.mockMessageList expect] retrieveMessageListWithSuccessBlock:[OCMArg checkWithBlock:^BOOL(id obj) {
        // Return the message
        [[[self.mockMessageList stub] andReturn:message] messageForID:@"MCRAP"];

        UAInboxMessageListCallbackBlock block = obj;
        block();
        return YES;
    }] withFailureBlock:OCMOCK_ANY];


    [[self.mockLandingPageOverlayController expect] showMessage:message];

    [self.action performWithArguments:arguments completionHandler:^(UAActionResult *result) {
        actionPerformed = YES;
        XCTAssertNil(result.value);
        XCTAssertNil(result.error);
        XCTAssertEqual(UAActionFetchResultNewData, result.fetchResult);
    }];

    XCTAssertTrue(actionPerformed);
    [self.mockLandingPageOverlayController verify];
}


/**
 * Test perform with a message ID when the message list fails to refresh should return
 * an error and a UAActionFetchResultFailed fetch result.
 */
- (void)testPerformMessageListFailsToUpdate {
    __block BOOL actionPerformed;

    UAActionArguments *arguments = [UAActionArguments argumentsWithValue:@"MCRAP" withSituation:UASituationManualInvocation];

    [[self.mockMessageList expect] retrieveMessageListWithSuccessBlock:OCMOCK_ANY
                                                      withFailureBlock:[OCMArg checkWithBlock:^BOOL(id obj) {
        UAInboxMessageListCallbackBlock block = obj;
        block();
        return YES;
    }]];

    [self.action performWithArguments:arguments completionHandler:^(UAActionResult *result) {
        actionPerformed = YES;
        XCTAssertNil(result.value);
        XCTAssertNotNil(result.error);
        XCTAssertEqual(UAActionFetchResultFailed, result.fetchResult);
    }];

    XCTAssertTrue(actionPerformed);
}

/**
 * Test the action looks up the message in the inbox message metadata if the placeholder
 * is set for the arguments value.
 */
- (void)testPerformWithPlaceHolderInboxMessageMetadata {
    __block BOOL actionPerformed;

    UAInboxMessage *message = [OCMockObject niceMockForClass:[UAInboxMessage class]];

    UAActionArguments *arguments = [UAActionArguments argumentsWithValue:@"auto"
                                                           withSituation:UASituationManualInvocation
                                                                metadata:@{UAActionMetadataInboxMessageKey: message}];

    [[self.mockLandingPageOverlayController expect] showMessage:message];

    [self.action performWithArguments:arguments completionHandler:^(UAActionResult *result) {
        actionPerformed = YES;
        XCTAssertNil(result.value);
        XCTAssertNil(result.error);
    }];

    XCTAssertTrue(actionPerformed);
    [self.mockLandingPageOverlayController verify];
}

/**
 * Test the action looks up the message ID in the push notification metadata if the placeholder
 * is set for the arguments value.
 */
- (void)testPerformWithPlaceHolderPushMessageMetadata {
    __block BOOL actionPerformed;

    UAInboxMessage *message = [OCMockObject niceMockForClass:[UAInboxMessage class]];

    // Only need the relevent bits to reference the correct message ID
    NSDictionary *notification = @{@"_uamid": @"MCRAP"};
    [[[self.mockMessageList stub] andReturn:message] messageForID:@"MCRAP"];

    UAActionArguments *arguments = [UAActionArguments argumentsWithValue:@"auto"
                                                           withSituation:UASituationManualInvocation
                                                                metadata:@{UAActionMetadataPushPayloadKey: notification}];

    [[self.mockLandingPageOverlayController expect] showMessage:message];

    [self.action performWithArguments:arguments completionHandler:^(UAActionResult *result) {
        actionPerformed = YES;
        XCTAssertNil(result.value);
        XCTAssertNil(result.error);
    }];


    XCTAssertTrue(actionPerformed);
    [self.mockLandingPageOverlayController verify];
}

@end
