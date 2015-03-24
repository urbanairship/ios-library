/*
 Copyright 2009-2015 Urban Airship Inc. All rights reserved.

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

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "UADisplayInboxAction.h"
#import "UAActionArguments+Internal.h"
#import "UAInbox.h"
#import "UAInboxPushHandler.h"
#import "UAInboxMessageList.h"
#import "UAirship.h"
#import "UAInboxMessage.h"

@interface UADisplayInboxActionTest : XCTestCase

@property (nonatomic, strong) UAActionArguments *arguments;
@property (nonatomic, strong) UADisplayInboxAction *action;
@property (nonatomic, strong) id mockInbox;
@property (nonatomic, strong) id mockPushHandler;
@property (nonatomic, strong) id mockPushHandlerDelegate;
@property (nonatomic, strong) id mockMessageList;
@property (nonatomic, strong) id mockAirship;
@end

@implementation UADisplayInboxActionTest

- (void)setUp {
    [super setUp];

    self.arguments = [[UAActionArguments alloc] init];
    self.arguments.situation = UASituationBackgroundInteractiveButton;

    self.action = [[UADisplayInboxAction alloc] init];
    self.mockPushHandler = [OCMockObject niceMockForClass:[UAInboxPushHandler class]];
    self.mockPushHandlerDelegate = [OCMockObject niceMockForProtocol:@protocol(UAInboxPushHandlerDelegate)];
    self.mockMessageList = [OCMockObject niceMockForClass:[UAInboxMessageList class]];
    self.mockInbox = [OCMockObject mockForClass:[UAInbox class]];
    self.mockAirship = [OCMockObject mockForClass:[UAirship class]];

    [[[self.mockAirship stub] andReturn:self.mockAirship] shared];
    [[[self.mockAirship stub] andReturn:self.mockInbox] inbox];

    [[[self.mockInbox stub] andReturn:self.mockMessageList] messageList];
    [[[self.mockInbox stub] andReturn:self.mockPushHandler] pushHandler];

    [[[self.mockPushHandler stub] andReturn:self.mockPushHandlerDelegate] delegate];
}

- (void)tearDown {
    [self.mockAirship stopMocking];
    [self.mockInbox stopMocking];
    [self.mockPushHandler stopMocking];
    [self.mockMessageList stopMocking];
    [self.mockPushHandlerDelegate stopMocking];

    [super tearDown];
}
/**
 * Test accepts valid string arguments in foreground situations.
 */
- (void)testAcceptsArguments {
    UASituation validSituations[5] = {
        UASituationForegroundPush,
        UASituationForegroundInteractiveButton,
        UASituationLaunchedFromPush,
        UASituationManualInvocation,
        UASituationWebViewInvocation
    };

    // Should accept a message ID
    self.arguments.value = @"MCRAP";
    for (int i = 0; i < 5; i++) {
        self.arguments.situation = validSituations[i];
        XCTAssertTrue([self.action acceptsArguments:self.arguments], @"action should accept situation %zd", validSituations[i]);
    }

    // Should accept a nil message ID
    self.arguments.value = nil;
    for (int i = 0; i < 5; i++) {
        self.arguments.situation = validSituations[i];
        XCTAssertTrue([self.action acceptsArguments:self.arguments], @"action should accept situation %zd", validSituations[i]);
    }
}

/**
 * Test accepts arguments rejects background situations.
 */
- (void)testAcceptsArgumentsRejectsBackgroundSituations {
    self.arguments.situation = UASituationBackgroundInteractiveButton;
    XCTAssertFalse([self.action acceptsArguments:self.arguments], @"action should reject situation UASituationBackgroundInteractiveButton");

    self.arguments.situation = UASituationBackgroundPush;
    XCTAssertFalse([self.action acceptsArguments:self.arguments], @"action should reject situation UASituationBackgroundPush");
}


/**
 * Test perform when the inbox message is available.
 */
- (void)testPerformAvailableInboxMessage {
    self.arguments.value = @"MCRAP";
    self.arguments.situation = UASituationLaunchedFromPush;

    __block UAActionResult *actionResult = nil;

    // Return a message for the action argument value
    UAInboxMessage *message = [OCMockObject niceMockForClass:[UAInboxMessage class]];
    [[[self.mockMessageList stub] andReturn:message] messageForID:@"MCRAP"];

    // Should notify the delegate to dipslay the inbox message
    [[self.mockPushHandlerDelegate expect] showInboxMessage:message];

    [self.action performWithArguments:self.arguments completionHandler:^(UAActionResult *result) {
        actionResult = result;
    }];

    XCTAssertNotNil(actionResult, @"perform did not call the completion handler");
    XCTAssertNil(actionResult.value, @"action result value should be empty.");
    XCTAssertNoThrow([self.mockPushHandlerDelegate verify], @"handler delegate should be notified of a MCRAP");
}

/**
 * Test perform when the inbox message is unavailable it calls showInbox.
 */
- (void)testPerformUnavailableInboxMessage {
    self.arguments.value = @"MCRAP";
    self.arguments.situation = UASituationLaunchedFromPush;

    __block UAActionResult *actionResult = nil;

    // Return a nil message for the action argument value
    [[[self.mockMessageList stub] andReturn:nil] messageForID:@"MCRAP"];

    // Should notify the delegate to display the inbox
    [[self.mockPushHandlerDelegate expect] showInbox];

    [self.action performWithArguments:self.arguments completionHandler:^(UAActionResult *result) {
        actionResult = result;
    }];

    XCTAssertNotNil(actionResult, @"perform did not call the completion handler");
    XCTAssertNil(actionResult.value, @"action result value should be empty.");
    XCTAssertNoThrow([self.mockPushHandlerDelegate verify], @"handler delegate should be notified of a MCRAP");
}

/**
 * Test perform when the inbox message ID is not specified it calls showInbox.
 */
- (void)testPerformAvailableNoMessageID {
    self.arguments.value = nil;
    self.arguments.situation = UASituationLaunchedFromPush;

    __block UAActionResult *actionResult = nil;

    // Should notify the delegate to display the inbox
    [[self.mockPushHandlerDelegate expect] showInbox];

    [self.action performWithArguments:self.arguments completionHandler:^(UAActionResult *result) {
        actionResult = result;
    }];

    XCTAssertNotNil(actionResult, @"perform did not call the completion handler");
    XCTAssertNil(actionResult.value, @"action result value should be empty.");
    XCTAssertNoThrow([self.mockPushHandlerDelegate verify], @"handler delegate should be notified of a MCRAP");
}

@end
