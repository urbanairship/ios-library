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

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "UAirship.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAIncomingInAppMessageAction.h"
#import "UAInAppMessage.h"
#import "UAInAppMessaging+Internal.h"
#import "UAActionArguments+Internal.h"
#import "UAAction+Internal.h"
#import "UAActionRegistry.h"
#import "UAInboxUtils.h"
#import "UAAnalytics.h"
#import "UAInAppResolutionEvent+Internal.h"

@interface UAIncomingInAppMessageActionTest : XCTestCase
@property(nonatomic, strong) NSDictionary *payload;
@property(nonatomic, strong) NSMutableDictionary *payloadWithOpenInbox;
@property(nonatomic, strong) UAIncomingInAppMessageAction *action;
@property(nonatomic, strong) UAActionArguments *arguments;
@property(nonatomic, strong) UAActionArguments *argumentsWithRichPush;
@property(nonatomic, strong) UAActionArguments *argumentsWithOpenInbox;
@property(nonatomic, strong) UAPreferenceDataStore *dataStore;
@property(nonatomic, strong) UAInAppMessaging *inAppMessaging;
@property(nonatomic, strong) id mockAnalytics;
@property(nonatomic, strong) id mockAirship;
@end

@implementation UAIncomingInAppMessageActionTest

- (void)setUp {
    [super setUp];
    self.action = [UAIncomingInAppMessageAction new];

    id expiry = @"2020-12-15T11:45:22";
    id extra = @{@"foo":@"bar", @"baz":@12345};
    id display = @{@"alert":@"hi!", @"type":@"banner", @"duration":@20, @"position":@"top", @"primary_color":@"#ffffffff", @"secondary_color":@"#ff00ff00"};

    id onClick = @{@"^d":@"http://google.com"};
    id onClickWithOpenInbox = [onClick mutableCopy];
    [onClickWithOpenInbox setObject:@"54321" forKey:@"^mc"];

    id actions = @{@"on_click":@{@"^d":@"http://google.com"}, @"button_group":@"ua_yes_no_foreground",
                   @"button_actions":@{@"yes":@{@"^+t": @"yes_tag"}, @"no":@{@"^+t": @"no_tag"}}};
    id actionsWithOpenInbox = [actions mutableCopy];
    [actionsWithOpenInbox setObject:onClickWithOpenInbox forKey:@"on_click"];

    self.payload = @{@"identifier":@"some identifier", @"expiry":expiry, @"extra":extra, @"display":display, @"actions":actions};
    self.payloadWithOpenInbox = [self.payload mutableCopy];
    [self.payloadWithOpenInbox setObject:actionsWithOpenInbox forKey:@"actions"];

    id fakePushPayload = @{@"_":@"some send ID"};
    id fakePushPayloadWithRichPush = [fakePushPayload mutableCopy];
    [fakePushPayloadWithRichPush setObject:@"12345" forKey:@"_uamid"];

    id metadata = @{UAActionMetadataPushPayloadKey:fakePushPayload};
    id metadataWithRichPush = @{UAActionMetadataPushPayloadKey:fakePushPayloadWithRichPush};

    self.arguments = [UAActionArguments argumentsWithValue:self.payload withSituation:UASituationManualInvocation metadata:metadata];

    // version of the arguments with APNS metatdata containing a rich push message ID
    self.argumentsWithRichPush = [UAActionArguments argumentsWithValue:self.payload withSituation:UASituationManualInvocation metadata:metadataWithRichPush];

    // version of the above containing a pre-existing open inbox on_click action
    self.argumentsWithOpenInbox = [UAActionArguments argumentsWithValue:self.payloadWithOpenInbox withSituation:UASituationManualInvocation metadata:metadataWithRichPush];

    self.dataStore = [UAPreferenceDataStore preferenceDataStoreWithKeyPrefix:@"ua_incoming_in_app_message_action.test."];

    self.mockAnalytics = [OCMockObject niceMockForClass:[UAAnalytics class]];

    self.inAppMessaging = [UAInAppMessaging inAppMessagingWithAnalytics:self.mockAnalytics dataStore:self.dataStore];

    self.mockAirship = [OCMockObject mockForClass:[UAirship class]];
    [[[self.mockAirship stub] andReturn:self.mockAirship] shared];
    [[[self.mockAirship stub] andReturn:self.inAppMessaging] inAppMessaging];
    [[[self.mockAirship stub] andReturn:self.mockAnalytics] analytics];
}

- (void)tearDown {
    [self.mockAnalytics stopMocking];
    [self.mockAirship stopMocking];
    [super tearDown];
}

/**
 * Test that action accepts NSDictionary arguments in non-launched from push situations
 */
- (void)testAcceptsArguments {

    UASituation validSituations[6] = {
        UASituationForegroundPush,
        UASituationBackgroundPush,
        UASituationForegroundInteractiveButton,
        UASituationBackgroundInteractiveButton,
        UASituationLaunchedFromPush,
        UASituationAutomation
    };

    for (int i = 0; i < 6; i++) {
        self.arguments.situation = validSituations[i];
        XCTAssertTrue([self.action acceptsArguments:self.arguments], @"action should accept NSDictionary values and non-launch from push situations");
    }
}

/**
 * Test that action rejects argument values that are not dictionaries.
 */
- (void)testRejectsNonDictionaryArgumentValues {
    self.arguments.value = nil;
    XCTAssertFalse([self.action acceptsArguments:self.arguments], @"action should reject a nil value");

    self.arguments.value = @"not a dictionary";
    XCTAssertFalse([self.action acceptsArguments:self.arguments], @"action should reject non-dictionary values");
}

/**
 * Test that manual and webview situations are rejected
 */
- (void)testRejectsManualAndWebViewSituations {
    // manual invocation (the default here) should be rejected
    XCTAssertFalse([self.action acceptsArguments:self.arguments]);

    self.arguments.situation = UASituationWebViewInvocation;

    // webview invocation should be rejected as well
    XCTAssertFalse([self.action acceptsArguments:self.arguments]);
}

/**
 * Test performWithArguments conforms to the following:
 * - Messages are saved in UASituationBackgroundPush/UASituationForegroundPush
 * - In this case if there's a message ID in the APNS metadata, an open inbox action is inserted,
 *   but only if one wasn't already present
 * - Pending messages are cleared and a direct open event is dispatched in UASituationLaunchedFromPush and 
 *   UASituationForegroundInteractiveButton/UASituationBackgroundInteractiveButton
 */
- (void)testPerform {
    [self validatePerformWithArguments:self.arguments];
    [self validatePerformWithArguments:self.argumentsWithOpenInbox];
    [self validatePerformWithArguments:self.argumentsWithRichPush];
}

// Helper methods for testPerfom

/**
 * Validate that in situations where the IAM should be saved as pending,
 * it is saved, and the send ID as well as the open inbox action (if applicable)
 * are set.
 */
- (void)validateSaveSituationWithArguments:(UAActionArguments *)args {

    id existingOpenInboxAction = [args.value valueForKeyPath:@"actions.on_click.^mc"];

    [self.action runWithArguments:args completionHandler:^(UAActionResult *result) {}];

    id apnsPayload = args.metadata[UAActionMetadataPushPayloadKey];
    NSString *sendId = apnsPayload[@"_"];

    UAInAppMessage *pending = [UAirship inAppMessaging].pendingMessage;

    // test that the push send id is set as the IAM identifier
    XCTAssert([pending.identifier isEqualToString:sendId]);

    NSString *inboxMessageID = [UAInboxUtils inboxMessageIDFromNotification:args.metadata[UAActionMetadataPushPayloadKey]];
    // test that if there was an inbox message ID, an open inbox action is inserted in its place
    // as long as there isn't already one there
    if (inboxMessageID) {
        BOOL containsOpenInboxAction = pending.onClick[kUADisplayInboxActionDefaultRegistryAlias] ||
        pending.onClick[kUADisplayInboxActionDefaultRegistryName];
        XCTAssertTrue(containsOpenInboxAction);
        // if there was already an open inbox action, it should not have been replaced
        if (existingOpenInboxAction) {
            XCTAssertEqualObjects(pending.onClick[@"^mc"], existingOpenInboxAction);
        }
    }
}

/**
 * Validate that in situations where the IAM should be cleared, it is
 * cleared and a direct open event is dispatched.
 */
- (void)validateClearSituationWithArgs:(UAActionArguments *)args {
    if ([UAirship inAppMessaging].pendingMessage) {
        // analytics should get a resolution event when the message is cleared
        [[self.mockAnalytics expect] addEvent:[OCMArg checkWithBlock:^(id obj) {
            if ([obj isKindOfClass:[UAInAppResolutionEvent class]]) {
                // check that it's the right kind of resolution
                NSString *type = [obj valueForKeyPath:@"data.resolution.type"];
                return [type isEqualToString:@"direct_open"];
            }

            return NO;
        }]];
        [self.action runWithArguments:args completionHandler:^(UAActionResult *result) {}];
        [self.mockAnalytics verify];

        UAInAppMessage *pending = [UAirship inAppMessaging].pendingMessage;
        XCTAssertNil(pending);
    }
}

/**
 * Helper for the method above, which preemptively sets the message as pending when
 * "pending" is YES. Useful for testing event dispatch, which should only occur if the
 * a pending message was actually deleted.
 */
- (void)validateClearSituationWithArgs:(UAActionArguments *)args pending:(BOOL)pending {
    if (pending) {
        [self.action runWithArguments:args completionHandler:^(UAActionResult *result) {}];
    }

    [self validateClearSituationWithArgs:args];

    // delete any pending message set above
    [UAirship inAppMessaging].pendingMessage = nil;
}


/**
 * Validate performWithArguments in all accepted situations
 */
- (void)validatePerformWithArguments:(UAActionArguments *)args {
    UASituation validSituations[5] = {
        UASituationForegroundPush,
        UASituationBackgroundPush,
        UASituationForegroundInteractiveButton,
        UASituationBackgroundInteractiveButton,
        UASituationLaunchedFromPush
    };

    for (int i = 0; i < 5; i++) {
        args.situation = validSituations[i];

        switch (args.situation) {
            case UASituationBackgroundPush:
            case UASituationForegroundPush:
                [self validateSaveSituationWithArguments:args];
                break;
            case UASituationLaunchedFromPush:
            case UASituationBackgroundInteractiveButton:
            case UASituationForegroundInteractiveButton:
                // test with both an existing pending message and no pending message
                [self validateClearSituationWithArgs:args pending:YES];
                [self validateClearSituationWithArgs:args pending:NO];
                break;
            default:
                XCTFail(@"Invalid situation: %ld", (long)args.situation);
        }
    }
}



@end
