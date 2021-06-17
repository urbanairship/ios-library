/* Copyright Airship and Contributors */

#import <UIKit/UIKit.h>
#import "UABaseTest.h"

#import "UAMessageCenterAction.h"
#import "UAActionArguments+Internal.h"
#import "UAirship+Internal.h"
#import "UAInboxMessage.h"
#import "UAMessageCenter.h"

@import AirshipCore;

@interface UAMessageCenterActionTest : UABaseTest
@property (nonatomic, strong) UAMessageCenterAction *action;
@property (nonatomic, copy) NSDictionary *notification;
@property (nonatomic, strong) id mockMessageCenter;
@end

@implementation UAMessageCenterActionTest

- (void)setUp {
    [super setUp];

    self.action = [[UAMessageCenterAction alloc] init];
    self.notification = @{@"_uamid": @"UAMID"};
    self.mockMessageCenter = [self mockForClass:[UAMessageCenter class]];
    [[[self.mockMessageCenter stub] andReturn:self.mockMessageCenter] shared];
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
        UASituationAutomation
    };

    UASituation rejectedSituations[3] = {
        UASituationBackgroundPush,
        UASituationForegroundPush,
        UASituationBackgroundInteractiveButton,
    };

    UAActionArguments *arguments = [[UAActionArguments alloc] init];

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
 * Test perform calls showMessageForID when an ID is provided.
 */
- (void)testShowMessageForID {
    // Set up the action arguments
    UAActionArguments *args = [UAActionArguments argumentsWithValue:@"MCRAP"
                                                      withSituation:UASituationManualInvocation];

    [[self.mockMessageCenter expect] displayMessageForID:@"MCRAP"];

    // Perform the action
    [self verifyActionPerformWithActionArguments:args];

    // Verify
    [self.mockMessageCenter verify];
}

/**
 * Test perform calls display  if no message ID is provided.
 */
- (void)testDisplayMessageCenter {
    // Set up the action arguments
    UAActionArguments *args = [UAActionArguments argumentsWithValue:[NSNull null]
                                                      withSituation:UASituationForegroundInteractiveButton];

    [[self.mockMessageCenter expect] display];

    // Perform the action
    [self verifyActionPerformWithActionArguments:args];

    // Verify
    [self.mockMessageCenter verify];
}

/**
 * Test the action looks up the message in the inbox message metadata if the placeholder
 * is set for the arguments value.
 */
- (void)testPerformWithPlaceHolderInboxMessageMetadata {
    UAActionArguments *args = [UAActionArguments argumentsWithValue:@"auto"
                                                      withSituation:UASituationManualInvocation
                                                           metadata:@{UAActionMetadataInboxMessageIDKey: @"NEAT"}];

    [[self.mockMessageCenter expect] displayMessageForID:@"NEAT"];

    // Perform the action
    [self verifyActionPerformWithActionArguments:args];
    
    // Verify
    [self.mockMessageCenter verify];
}

/**
 * Test the action looks up the message ID in the push notification metadata if the placeholder
 * is set for the arguments value.
 */
- (void)testPerformWithPlaceHolderPushMessageMetadata {
    UAActionArguments *args = [UAActionArguments argumentsWithValue:@"auto"
                                                      withSituation:UASituationManualInvocation
                                                           metadata:@{UAActionMetadataPushPayloadKey: self.notification}];

    [[self.mockMessageCenter expect] displayMessageForID:self.notification[@"_uamid"]];

    // Perform the action
    [self verifyActionPerformWithActionArguments:args];

    // Verify
    [self.mockMessageCenter verify];
}

#pragma mark -
#pragma mark Test helpers

- (void)verifyActionPerformWithActionArguments:(UAActionArguments *)args {
    XCTestExpectation *actionRan = [self expectationWithDescription:@"action ran"];
    [self.action performWithArguments:args completionHandler:^(UAActionResult *result) {
        XCTAssertNotNil(result, @"perform did not call the completion handler");
        XCTAssertNil(result.value, @"action result value should be empty");
        XCTAssertEqual(UAActionFetchResultNoData, result.fetchResult, @"unexpected action fetch result");
        [actionRan fulfill];
    }];

    [self waitForTestExpectations];
}

@end
