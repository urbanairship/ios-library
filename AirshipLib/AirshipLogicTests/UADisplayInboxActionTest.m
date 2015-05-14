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
#import "UAInbox+Internal.h"
#import "UAInboxPushHandler.h"
#import "UAInboxMessageList.h"
#import "UAirship.h"
#import "UAInboxMessage.h"
#import "UALandingPageOverlayController.h"

@interface UADisplayInboxActionTest : XCTestCase

@property (nonatomic, strong) UADisplayInboxAction *action;
@property (nonatomic, strong) NSDictionary *notification;

@property (nonatomic, strong) id mockMessage;
@property (nonatomic, strong) id mockPushHandlerDelegate;
@property (nonatomic, strong) id mockInboxDelegate;

@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) id mockMessageList;
@property (nonatomic, strong) id mockLandingPageOverlayController;

@end

@implementation UADisplayInboxActionTest

- (void)setUp {
    [super setUp];

    self.action = [[UADisplayInboxAction alloc] init];
    self.mockPushHandlerDelegate = [OCMockObject niceMockForProtocol:@protocol(UAInboxPushHandlerDelegate)];
    self.mockInboxDelegate = [OCMockObject niceMockForProtocol:@protocol(UAInboxDelegate)];

    self.notification = @{@"_uamid": @"UAMID"};

    self.mockMessage = [OCMockObject niceMockForClass:[UAInboxMessage class]];
    self.mockMessageList = [OCMockObject niceMockForClass:[UAInboxMessageList class]];

    self.mockAirship = [OCMockObject niceMockForClass:[UAirship class]];
    [[[self.mockAirship stub] andReturn:self.mockAirship] shared];

    UAInbox *inbox = [[UAInbox alloc] init];
    inbox.pushHandler = [[UAInboxPushHandler alloc] init];
    inbox.messageList = self.mockMessageList;
    [[[self.mockAirship stub] andReturn:inbox] inbox];

    self.mockLandingPageOverlayController = [OCMockObject niceMockForClass:[UALandingPageOverlayController class]];
}

- (void)tearDown {
    [self.mockAirship stopMocking];
    [self.mockMessageList stopMocking];
    [self.mockPushHandlerDelegate stopMocking];
    [self.mockInboxDelegate stopMocking];
    [self.mockLandingPageOverlayController stopMocking];

    [super tearDown];
}


/**
 * Test the action accepts any foreground situation.
 */
- (void)testAcceptsArguments {
    UASituation validSituations[5] = {
        UASituationForegroundInteractiveButton,
        UASituationLaunchedFromPush,
        UASituationManualInvocation,
        UASituationWebViewInvocation,
        UASituationForegroundPush
    };

    UASituation rejectedSituations[2] = {
        UASituationBackgroundPush,
        UASituationBackgroundInteractiveButton,
    };

    UAActionArguments *arguments = [[UAActionArguments alloc] init];

    for (int i = 0; i < 5; i++) {
        arguments.situation = validSituations[i];
        XCTAssertTrue([self.action acceptsArguments:arguments], @"action should accept situation %zd", validSituations[i]);
    }

    for (int i = 0; i < 2; i++) {
        arguments.situation = rejectedSituations[i];
        XCTAssertFalse([self.action acceptsArguments:arguments], @"action should reject situation %zd", rejectedSituations[i]);
    }
}

/**
 * Test perform calls showInboxMessage: on the inbox delegate
 * when the message is already available in the message list.
 */
- (void)testPerformShowInboxMessageMessageAvailable {
    [UAirship inbox].delegate = self.mockInboxDelegate;

    // Set up the action arguments
    UAActionArguments *args = [UAActionArguments argumentsWithValue:@"MCRAP"
                                                      withSituation:UASituationManualInvocation];

    // Return the message for the message ID
    [[[self.mockMessageList stub] andReturn:self.mockMessage] messageForID:@"MCRAP"];

    // Should notify the delegate of the message
    [[self.mockInboxDelegate expect] showInboxMessage:self.mockMessage];

    // Perform the action
    [self verifyActionPerformWithActionArguments:args expectedFetchResult:UAActionFetchResultNoData];

    // Verify delegate calls
    [self.mockInboxDelegate verify];
}

/**
 * Test perform calls showInboxMessage: on the inbox delegate
 * after the message list is refreshed.
 */
- (void)testPerformShowInboxMessageAfterMessageListRefresh {
    [UAirship inbox].delegate = self.mockInboxDelegate;

    // Set up the action arguments
    UAActionArguments *args = [UAActionArguments argumentsWithValue:@"MCRAP"
                                                      withSituation:UASituationForegroundInteractiveButton];

    // Should notify the delegate of the notification
    [[self.mockInboxDelegate expect] showInboxMessage:self.mockMessage];

    // Need to stub a message list result so the action is able to finish
    [self stubMessageListRefreshWithSuccessBlock:^{
        [[[self.mockMessageList stub] andReturn:self.mockMessage] messageForID:@"MCRAP"];
    }];

    // Perform the action
    [self verifyActionPerformWithActionArguments:args expectedFetchResult:UAActionFetchResultNewData];

    // Verify delegate calls
    [self.mockInboxDelegate verify];
}

/**
 * Test perform calls showInbox on the inbox delegate if the message is unavailable
 * in the message list and the message list is able to be refreshed.
 */
- (void)testPerformShowInboxAfterMessageListRefresh {
    [UAirship inbox].delegate = self.mockInboxDelegate;

    // Set up the action arguments
    UAActionArguments *args = [UAActionArguments argumentsWithValue:@"MCRAP"
                                                      withSituation:UASituationForegroundInteractiveButton];

    // Should notify the delegate of the notification
    [[self.mockInboxDelegate expect] showInbox];

    // Need to stub a message list result so the action is able to finish
    [self stubMessageListRefreshWithSuccessBlock:nil];

    // Perform the action
    [self verifyActionPerformWithActionArguments:args expectedFetchResult:UAActionFetchResultNewData];

    // Verify delegate calls
    [self.mockInboxDelegate verify];
}

/**
 * Test perform calls showInbox on the inbox delegate if the message is unavailable
 * after the message list is refreshed.
 */
- (void)testPerformShowInboxMessageListFailedToRefresh {
    [UAirship inbox].delegate = self.mockInboxDelegate;

    // Set up the action arguments
    UAActionArguments *args = [UAActionArguments argumentsWithValue:@"MCRAP"
                                                      withSituation:UASituationWebViewInvocation];

    // Stub the message list to fail on refresh
    [self stubMessageListRefreshWithFailureBlock:nil];

    // Should notify the delegate of the message
    [[self.mockInboxDelegate expect] showInbox];

    // Perform the action
    [self verifyActionPerformWithActionArguments:args expectedFetchResult:UAActionFetchResultFailed];
    
    // Verify delegate calls
    [self.mockInboxDelegate verify];
}

/**
 * Test the action looks up the message in the inbox message metadata if the placeholder
 * is set for the arguments value.
 */
- (void)testPerfromWithPlaceHolderInboxMessageMetadata {
    [UAirship inbox].delegate = self.mockInboxDelegate;

    UAActionArguments *args = [UAActionArguments argumentsWithValue:@"MESSAGE_ID"
                                                      withSituation:UASituationManualInvocation
                                                           metadata:@{UAActionMetadataInboxMessageKey: self.mockMessage}];

    // Should notify the delegate of the message
    [[self.mockInboxDelegate expect] showInboxMessage:self.mockMessage];

    // Perform the action
    [self verifyActionPerformWithActionArguments:args expectedFetchResult:UAActionFetchResultNoData];

    // Verify delegate calls
    [self.mockInboxDelegate verify];
}

/**
 * Test the action looks up the message ID in the push notification metadata if the placeholder
 * is set for the arguments value.
 */
- (void)testPerfromWithPlaceHolderPushMessageMetadata {
    [UAirship inbox].delegate = self.mockInboxDelegate;

    UAActionArguments *args = [UAActionArguments argumentsWithValue:@"MESSAGE_ID"
                                                      withSituation:UASituationManualInvocation
                                                           metadata:@{UAActionMetadataPushPayloadKey: self.notification}];

    // Have the message list return the message for the notification's _uamid
    [[[self.mockMessageList stub] andReturn:self.mockMessage] messageForID:self.notification[@"_uamid"]];

    // Should notify the delegate of the message
    [[self.mockInboxDelegate expect] showInboxMessage:self.mockMessage];

    // Perform the action
    [self verifyActionPerformWithActionArguments:args expectedFetchResult:UAActionFetchResultNoData];

    // Verify delegate calls
    [self.mockInboxDelegate verify];
}


/**
 * Test the action performing with a message will fall back to displaying the
 * message in a landing page if no delegate is available.
 */
- (void)testPerformFallsBackLandingPageController {
    // Set up the action arguments
    UAActionArguments *args = [UAActionArguments argumentsWithValue:@"MCRAP"
                                                      withSituation:UASituationManualInvocation];

    // Return the message for the message ID
    [[[self.mockMessageList stub] andReturn:self.mockMessage] messageForID:@"MCRAP"];

    // Should display in the landing page
    [[self.mockLandingPageOverlayController expect] showMessage:self.mockMessage];

    // Perform the action
    [self verifyActionPerformWithActionArguments:args expectedFetchResult:UAActionFetchResultNoData];

    // Verify it was displayed
    [self.mockLandingPageOverlayController verify];
}


#pragma mark -
#pragma mark Test helpers

- (void)verifyActionPerformWithActionArguments:(UAActionArguments *)args expectedFetchResult:(UAActionFetchResult)fetchResult{
    __block UAActionResult *actionResult = nil;

    [self.action performWithArguments:args completionHandler:^(UAActionResult *result) {
        actionResult = result;
    }];

    XCTAssertNotNil(actionResult, @"perform did not call the completion handler");
    XCTAssertNil(actionResult.value, @"action result value should be empty");
    XCTAssertEqual(fetchResult, actionResult.fetchResult, @"unexpected action fetch result");
}

- (void)stubMessageListRefreshWithSuccessBlock:(void (^)())block {
    [[self.mockMessageList stub] retrieveMessageListWithSuccessBlock:[OCMArg checkWithBlock:^BOOL(id obj) {
        if (block) {
            block();
        }
        UAInboxMessageListCallbackBlock callback = obj;
        callback();
        return YES;
    }] withFailureBlock:OCMOCK_ANY];
}

- (void)stubMessageListRefreshWithFailureBlock:(void (^)())block {
    [[self.mockMessageList stub] retrieveMessageListWithSuccessBlock:OCMOCK_ANY
                                                      withFailureBlock:[OCMArg checkWithBlock:^BOOL(id obj) {

        if (block) {
            block();
        }
        UAInboxMessageListCallbackBlock callback = obj;
        callback();
        return YES;
    }]];
}


#pragma mark -
#pragma mark Deprecated UAInboxPushHandlerDelegate tests

/**
 * Test perform calls richPushNotificationArrived: on the deprecated inbox delegate
 * in situation UASituationForegroundPush when a message ID is available.
 */
- (void)testPerfromSendsRichPushNotificationArrivedDeprecated {
    [UAirship inbox].pushHandler.delegate = self.mockPushHandlerDelegate;

    // Set up the action arguments for UASituationForegroundPush
    UAActionArguments *args = [UAActionArguments argumentsWithValue:@"MCRAP"
                                                      withSituation:UASituationForegroundPush
                                                           metadata:@{UAActionMetadataPushPayloadKey: self.notification}];

    // Return the message for the message ID
    [[[self.mockMessageList stub] andReturn:self.mockMessage] messageForID:@"MCRAP"];

    // Should notify the delegate of the notification
    [[self.mockPushHandlerDelegate expect] richPushNotificationArrived:self.notification];

    // Perform the action
    [self verifyActionPerformWithActionArguments:args expectedFetchResult:UAActionFetchResultNoData];

    // Verify the delegate was called
    [self.mockPushHandlerDelegate verify];
}

/**
 * Test perform calls launchRichPushMessageAvailable: on the deprecated inbox delegate
 * in situation UASituationForegroundPush when the message is available.
 */
- (void)testPerformRichPushMessageAvailableDeprecated {
    [UAirship inbox].pushHandler.delegate = self.mockPushHandlerDelegate;

    // Set up the action arguments for UASituationForegroundPush for MCRAP
    UAActionArguments *args = [UAActionArguments argumentsWithValue:@"MCRAP"
                                                      withSituation:UASituationForegroundPush
                                                           metadata:@{UAActionMetadataPushPayloadKey: self.notification}];

    // Return the message for the message ID
    [[[self.mockMessageList stub] andReturn:self.mockMessage] messageForID:@"MCRAP"];

    // Should notify the delegate of the notification
    [[self.mockPushHandlerDelegate expect] richPushMessageAvailable:self.mockMessage];

    // Perform the action
    [self verifyActionPerformWithActionArguments:args expectedFetchResult:UAActionFetchResultNoData];

    // Verify delegate calls
    [self.mockPushHandlerDelegate verify];
}

/**
 * Test perform calls applicationLaunchedWithRichPushNotification: on the deprecated inbox delegate
 * in situation UASituationLaunchedFromPush when a message ID is available.
 */
- (void)testPerfromSendsLaunchRichPushNotificationArrivedDeprecated {
    [UAirship inbox].pushHandler.delegate = self.mockPushHandlerDelegate;

    // Set up the action arguments for UASituationLaunchedFromPush
    UAActionArguments *args = [UAActionArguments argumentsWithValue:@"MCRAP"
                                                      withSituation:UASituationLaunchedFromPush
                                                           metadata:@{UAActionMetadataPushPayloadKey: self.notification}];

    // Return the message for the message ID
    [[[self.mockMessageList stub] andReturn:self.mockMessage] messageForID:@"MCRAP"];

    // Should notify the delegate of the notification
    [[self.mockPushHandlerDelegate expect] applicationLaunchedWithRichPushNotification:self.notification];

    // Perform the action
    [self verifyActionPerformWithActionArguments:args expectedFetchResult:UAActionFetchResultNoData];

    // Verify delegate calls
    [self.mockPushHandlerDelegate verify];
}


/**
 * Test perform calls launchRichPushMessageAvailable: on the deprecated inbox delegate
 * in situation UASituationLaunchedFromPush when the message is available.
 */
- (void)testPerformLaunchRichPushMessageAvailableDeprecated {
    [UAirship inbox].pushHandler.delegate = self.mockPushHandlerDelegate;

    // Set up the action arguments for UASituationLaunchedFromPush
    UAActionArguments *args = [UAActionArguments argumentsWithValue:@"MCRAP"
                                                      withSituation:UASituationLaunchedFromPush
                                                           metadata:@{UAActionMetadataPushPayloadKey: self.notification}];

    // Return the message for the message ID
    [[[self.mockMessageList stub] andReturn:self.mockMessage] messageForID:@"MCRAP"];

    // Should notify the delegate of the message
    [[self.mockPushHandlerDelegate expect] launchRichPushMessageAvailable:self.mockMessage];

    // Perform the action
    [self verifyActionPerformWithActionArguments:args expectedFetchResult:UAActionFetchResultNoData];

    // Verify delegate calls
    [self.mockPushHandlerDelegate verify];
}

/**
 * Test perform calls showInboxMessage: on the deprecated inbox delegate
 * when the message is already available in the message list.
 */
- (void)testPerformShowInboxMessageMessageAvailableDeprecated {
    [UAirship inbox].pushHandler.delegate = self.mockPushHandlerDelegate;

    // Set up the action arguments
    UAActionArguments *args = [UAActionArguments argumentsWithValue:@"MCRAP"
                                                      withSituation:UASituationManualInvocation];

    // Return the message for the message ID
    [[[self.mockMessageList stub] andReturn:self.mockMessage] messageForID:@"MCRAP"];

    // Should notify the delegate of the message
    [[self.mockPushHandlerDelegate expect] showInboxMessage:self.mockMessage];

    // Perform the action
    [self verifyActionPerformWithActionArguments:args expectedFetchResult:UAActionFetchResultNoData];

    // Verify delegate calls
    [self.mockPushHandlerDelegate verify];
}

/**
 * Test perform calls showInboxMessage: on the deprecated inbox delegate
 * after the message list is refreshed.
 */
- (void)testPerformShowInboxMessageAfterMessageListRefreshDeprecated {
    [UAirship inbox].pushHandler.delegate = self.mockPushHandlerDelegate;

    // Set up the action arguments
    UAActionArguments *args = [UAActionArguments argumentsWithValue:@"MCRAP"
                                                      withSituation:UASituationForegroundInteractiveButton];

    // Should notify the delegate of the notification
    [[self.mockPushHandlerDelegate expect] showInboxMessage:self.mockMessage];

    // Need to stub a message list result so the action is able to finish
    [self stubMessageListRefreshWithSuccessBlock:^{
        [[[self.mockMessageList stub] andReturn:self.mockMessage] messageForID:@"MCRAP"];
    }];

    // Perform the action
    [self verifyActionPerformWithActionArguments:args expectedFetchResult:UAActionFetchResultNewData];

    // Verify delegate calls
    [self.mockPushHandlerDelegate verify];
}

/**
 * Test perform calls showInbox on the deprecated inbox delegate if the message
 * is unavailable in the message list and the message list is able to be refreshed.
 */
- (void)testPerformShowInboxAfterMessageListRefreshDeprecated {
    [UAirship inbox].pushHandler.delegate = self.mockPushHandlerDelegate;

    // Set up the action arguments
    UAActionArguments *args = [UAActionArguments argumentsWithValue:@"MCRAP"
                                                      withSituation:UASituationForegroundInteractiveButton];

    // Should notify the delegate of the notification
    [[self.mockPushHandlerDelegate expect] showInbox];

    // Need to stub a message list result so the action is able to finish
    [self stubMessageListRefreshWithSuccessBlock:nil];

    // Perform the action
    [self verifyActionPerformWithActionArguments:args expectedFetchResult:UAActionFetchResultNewData];

    // Verify delegate calls
    [self.mockPushHandlerDelegate verify];
}

/**
 * Test perform calls showInbox on the deprecated inbox delegate if the message
 * is unavailable in the message list and the message list fails to refresh.
 */
- (void)testPerformShowInboxMessageListFailedToRefreshDeprecated {
    [UAirship inbox].pushHandler.delegate = self.mockPushHandlerDelegate;

    // Set up the action arguments
    UAActionArguments *args = [UAActionArguments argumentsWithValue:@"MCRAP"
                                                      withSituation:UASituationWebViewInvocation];

    // Stub the message list to fail on refresh
    [self stubMessageListRefreshWithFailureBlock:nil];

    // Should notify the delegate of the message
    [[self.mockPushHandlerDelegate expect] showInbox];

    // Perform the action
    [self verifyActionPerformWithActionArguments:args expectedFetchResult:UAActionFetchResultFailed];

    // Verify delegate calls
    [self.mockPushHandlerDelegate verify];
}


@end
