/* Copyright Airship and Contributors */

#import <UIKit/UIKit.h>
#import "UABaseTest.h"

#import "UAMessageCenterAction.h"
#import "UAActionArguments+Internal.h"
#import "UAInbox+Internal.h"
#import "UAInboxMessageList.h"
#import "UAirship+Internal.h"
#import "UAInboxMessage.h"
#import "UAMessageCenter.h"
#import "UAPreferenceDataStore+Internal.h"

@interface UAMessageCenterActionTest : UABaseTest

@property (nonatomic, strong) UAMessageCenterAction *action;
@property (nonatomic, strong) NSDictionary *notification;

@property (nonatomic, strong) id mockInbox;
@property (nonatomic, strong) id mockInboxDelegate;

@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) id mockMessageCenter;
@property (nonatomic, strong) id mockMessage;
@end

@implementation UAMessageCenterActionTest

- (void)setUp {
    [super setUp];

    self.action = [[UAMessageCenterAction alloc] init];
    self.mockInboxDelegate = [self mockForProtocol:@protocol(UAInboxDelegate)];
    self.notification = @{@"_uamid": @"UAMID"};

    self.mockAirship = [self mockForClass:[UAirship class]];
    [UAirship setSharedAirship:self.mockAirship];

    self.mockMessageCenter = [self mockForClass:[UAMessageCenter class]];
    [[[self.mockAirship stub] andReturn:self.mockMessageCenter] sharedMessageCenter];

    self.mockInbox = [self mockForClass:[UAInbox class]];
    [[[self.mockAirship stub] andReturn:self.mockInbox] sharedInbox];

    self.mockMessage = [self mockForClass:[UAInboxMessage class]];
    [[[self.mockMessage stub] andReturn:@"MCRAP"] messageID];
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

    [[self.mockInboxDelegate expect] showMessageForID:@"MCRAP"];
    [[[self.mockInbox stub] andReturn:self.mockInboxDelegate] delegate];

    // Perform the action
    [self verifyActionPerformWithActionArguments:args];

    // Verify delegate calls
    [self.mockInboxDelegate verify];
}

/**
 * Test perform calls showInbox if no message ID is provided.
 */
- (void)testShowInbox {
    [[[self.mockInbox stub] andReturn:self.mockInboxDelegate] delegate];

    // Set up the action arguments
    UAActionArguments *args = [UAActionArguments argumentsWithValue:[NSNull null]
                                                      withSituation:UASituationForegroundInteractiveButton];

    [[self.mockInboxDelegate expect] showInbox];
    [[[self.mockInbox stub] andReturn:self.mockInboxDelegate] delegate];

    // Perform the action
    [self verifyActionPerformWithActionArguments:args];

    // Verify delegate calls
    [self.mockInboxDelegate verify];
}

/**
 * Test the action looks up the message in the inbox message metadata if the placeholder
 * is set for the arguments value.
 */
- (void)testPerformWithPlaceHolderInboxMessageMetadata {
    [[[self.mockInbox stub] andReturn:self.mockInboxDelegate] delegate];

    UAActionArguments *args = [UAActionArguments argumentsWithValue:@"auto"
                                                      withSituation:UASituationManualInvocation
                                                           metadata:@{UAActionMetadataInboxMessageKey: self.mockMessage}];

    // Should notify the delegate of the message
    [[self.mockInboxDelegate expect] showMessageForID:((UAInboxMessage *)self.mockMessage).messageID];

    // Perform the action
    [self verifyActionPerformWithActionArguments:args];
    
    // Verify delegate calls
    [self.mockInboxDelegate verify];
}

/**
 * Test the action looks up the message ID in the push notification metadata if the placeholder
 * is set for the arguments value.
 */
- (void)testPerformWithPlaceHolderPushMessageMetadata {
    [[[self.mockInbox stub] andReturn:self.mockInboxDelegate] delegate];

    UAActionArguments *args = [UAActionArguments argumentsWithValue:@"auto"
                                                      withSituation:UASituationManualInvocation
                                                           metadata:@{UAActionMetadataPushPayloadKey: self.notification}];

    // Should notify the delegate of the message
    [[self.mockInboxDelegate expect] showMessageForID:self.notification[@"_uamid"]];

    // Perform the action
    [self verifyActionPerformWithActionArguments:args];

    // Verify delegate calls
    [self.mockInboxDelegate verify];
}


/**
 * Test the action performing with a message will fall back to displaying the
 * message in the default message center if no delegate is available.
 */
- (void)testPerformWithMessageFallsBackDefaultMessageCenter {
    // Set up the action arguments
    UAActionArguments *args = [UAActionArguments argumentsWithValue:@"MCRAP"
                                                      withSituation:UASituationManualInvocation];

    // Should display in the default message center
    [[self.mockMessageCenter expect] displayMessageForID:@"MCRAP"];

    // Perform the action
    [self verifyActionPerformWithActionArguments:args];
    
    // Verify it was displayed
    [self.mockMessageCenter verify];
}

/**
 * Test the action performing with a message will fall back to displaying the
 * the default message center if no delegate is available.
 */
- (void)testPerformWFallsBackDefaultMessageCenter {
    // Set up the action arguments
    UAActionArguments *args = [UAActionArguments argumentsWithValue:[NSNull null]
                                                      withSituation:UASituationManualInvocation];

    // Should display in the default message center
    [[self.mockMessageCenter expect] display];

    // Perform the action
    [self verifyActionPerformWithActionArguments:args];

    // Verify it was displayed
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
