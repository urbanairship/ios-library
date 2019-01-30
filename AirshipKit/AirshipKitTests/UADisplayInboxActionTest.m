/* Copyright 2010-2019 Urban Airship and Contributors */

#import <UIKit/UIKit.h>
#import "UABaseTest.h"

#import "UADisplayInboxAction.h"
#import "UAActionArguments+Internal.h"
#import "UAInbox+Internal.h"
#import "UAInboxMessageList.h"
#import "UAirship.h"
#import "UAInboxMessage.h"
#import "UAMessageCenter.h"
#import "UAPreferenceDataStore+Internal.h"

@interface UADisplayInboxActionTest : UABaseTest

@property (nonatomic, strong) UADisplayInboxAction *action;
@property (nonatomic, strong) NSDictionary *notification;
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;

@property (nonatomic, strong) id mockMessage;
@property (nonatomic, strong) id mockInbox;
@property (nonatomic, strong) id mockInboxDelegate;

@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) id mockMessageList;
@property (nonatomic, strong) id mockMessageCenter;

@property (nonatomic, strong) id mockUser;
@property (nonatomic, strong) id mockConfig;

@end

@implementation UADisplayInboxActionTest

- (void)setUp {
    [super setUp];

    self.action = [[UADisplayInboxAction alloc] init];
    
    self.dataStore = [UAPreferenceDataStore preferenceDataStoreWithKeyPrefix:[NSString stringWithFormat:@"uadisplayinbox.test.%@",self.name]];
    [self.dataStore removeAll]; // start with an empty datastore

    self.mockInboxDelegate = [self mockForProtocol:@protocol(UAInboxDelegate)];

    self.notification = @{@"_uamid": @"UAMID"};

    self.mockMessage = [self mockForClass:[UAInboxMessage class]];
    OCMStub([self.mockMessage messageID]).andReturn(@"MCRAP");
    self.mockMessageList = [self mockForClass:[UAInboxMessageList class]];
    self.mockMessageCenter = [self mockForClass:[UAMessageCenter class]];

    self.mockAirship = [self mockForClass:[UAirship class]];
    [[[self.mockAirship stub] andReturn:self.mockAirship] shared];
    [[[self.mockAirship stub] andReturn:self.mockMessageCenter] messageCenter];

    self.mockInbox = [self mockForClass:[UAInbox class]];
    [[[self.mockInbox stub] andReturn:self.mockMessageList] messageList];
    [[[self.mockAirship stub] andReturn:self.mockInbox] inbox];

}

- (void)tearDown {
    [self.dataStore removeAll];

    [super tearDown];
}


/**
 * Test the action accepts any foreground situation.
 */
- (void)testAcceptsArguments {
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
 * Test perform calls showInboxMessageForID: on the inbox delegate
 * when the message is already available in the message list.
 */
- (void)testPerformShowInboxMessageForIDMessageAvailable {
    [[[self.mockInbox stub] andReturn:self.mockInboxDelegate] delegate];
    
    // Set up the action arguments
    UAActionArguments *args = [UAActionArguments argumentsWithValue:@"MCRAP"
                                                      withSituation:UASituationManualInvocation];
    
    // Return the message for the message ID
    [[[self.mockMessageList stub] andReturn:self.mockMessage] messageForID:@"MCRAP"];
    
    // Should notify the delegate of the message
    XCTestExpectation *expectation = [self expectationWithDescription:@"showMessageForID called"];
    [[[self.mockInboxDelegate expect] andDo:^(NSInvocation *invocation) {
        [expectation fulfill];
    }] showMessageForID:@"MCRAP"];
    
    // Perform the action
    [self verifyActionPerformWithActionArguments:args expectedFetchResult:UAActionFetchResultNoData];
    
    // Wait for it to complete
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    // Verify delegate calls
    [self.mockInboxDelegate verify];
}

/**
 * Test perform calls showInboxMessageForID: on the inbox delegate
 * after the message list is refreshed.
 */
- (void)testPerformShowInboxMessageForIDAfterMessageListRefresh {
    [[[self.mockInbox stub] andReturn:self.mockInboxDelegate] delegate];
    
    // Set up the action arguments
    UAActionArguments *args = [UAActionArguments argumentsWithValue:@"MCRAP"
                                                      withSituation:UASituationForegroundInteractiveButton];
    
    // Should notify the delegate of the notification
    XCTestExpectation *expectation = [self expectationWithDescription:@"showMessageForID called"];
    [[[self.mockInboxDelegate expect] andDo:^(NSInvocation *invocation) {
        [expectation fulfill];
    }] showMessageForID:@"MCRAP"];
    
    // Need to stub a message list result so the action is able to finish
    [[[self.mockMessageList stub] andReturn:self.mockMessage] messageForID:@"MCRAP"];
    
    // Perform the action
    [self verifyActionPerformWithActionArguments:args expectedFetchResult:UAActionFetchResultNoData];
    
    // Wait for it to complete
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    // Verify delegate calls
    [self.mockInboxDelegate verify];
}

/**
 * Test perform calls showInbox on the inbox delegate if the message is unavailable
 * in the message list and the message list is able to be refreshed.
 */
- (void)testPerformShowInboxAfterMessageListRefresh {
    [[[self.mockInbox stub] andReturn:self.mockInboxDelegate] delegate];

    // Set up the action arguments
    UAActionArguments *args = [UAActionArguments argumentsWithValue:@"MCRAP"
                                                      withSituation:UASituationForegroundInteractiveButton];

    // Should notify the delegate of the notification
    XCTestExpectation *expectation = [self expectationWithDescription:@"showMessageForID called"];
    [[[self.mockInboxDelegate expect] andDo:^(NSInvocation *invocation) {
        [expectation fulfill];
    }] showMessageForID:@"MCRAP"];

    // Need to stub a message list result so the action is able to finish
    [self stubMessageListRefreshWithSuccessBlock:^{
        [[[self.mockMessageList stub] andReturn:self.mockMessage] messageForID:@"MCRAP"];
    }];

    // Perform the action
    [self verifyActionPerformWithActionArguments:args expectedFetchResult:UAActionFetchResultNewData];

    // Wait for it to complete
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    // Verify delegate calls
    [self.mockInboxDelegate verify];
}

/**
 * Test perform calls showInbox on the inbox delegate if the message is unavailable
 * after the message list is refreshed.
 */
- (void)testPerformShowInboxMessageListFailedToRefresh {
    [[[self.mockInbox stub] andReturn:self.mockInboxDelegate] delegate];

    // Set up the action arguments
    UAActionArguments *args = [UAActionArguments argumentsWithValue:@"MCRAP"
                                                      withSituation:UASituationWebViewInvocation];

    // Stub the message list to fail on refresh
    [self stubMessageListRefreshWithFailureBlock:nil];

    // Should notify the delegate of the message
    XCTestExpectation *expectation = [self expectationWithDescription:@"showInbox called"];
    [[[self.mockInboxDelegate expect] andDo:^(NSInvocation *invocation) {
        [expectation fulfill];
    }] showInbox];

    // Perform the action
    [self verifyActionPerformWithActionArguments:args expectedFetchResult:UAActionFetchResultFailed];
    
    // Wait for it to complete
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
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
    XCTestExpectation *expectation = [self expectationWithDescription:@"showMessageForID called"];
    [[[self.mockInboxDelegate expect] andDo:^(NSInvocation *invocation) {
        [expectation fulfill];
    }] showMessageForID:((UAInboxMessage *)self.mockMessage).messageID];

    // Perform the action
    [self verifyActionPerformWithActionArguments:args expectedFetchResult:UAActionFetchResultNoData];

    // Wait for it to complete
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
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

    // Have the message list return the message for the notification's _uamid
    [[[self.mockMessageList stub] andReturn:self.mockMessage] messageForID:self.notification[@"_uamid"]];

    // Should notify the delegate of the message
    XCTestExpectation *expectation = [self expectationWithDescription:@"showMessageForID called"];
    [[[self.mockInboxDelegate expect] andDo:^(NSInvocation *invocation) {
        [expectation fulfill];
    }] showMessageForID:((UAInboxMessage *)self.mockMessage).messageID];

    // Perform the action
    [self verifyActionPerformWithActionArguments:args expectedFetchResult:UAActionFetchResultNoData];

    // Wait for it to complete
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
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

    // Return the message for the message ID
    [[[self.mockMessageList stub] andReturn:self.mockMessage] messageForID:@"MCRAP"];

    // Should display in the default message center
    XCTestExpectation *expectation = [self expectationWithDescription:@"displayMessageForID called"];
    [[[self.mockMessageCenter expect] andDo:^(NSInvocation *invocation) {
        [expectation fulfill];
    }] displayMessageForID:((UAInboxMessage *)self.mockMessage).messageID];

    // Perform the action
    [self verifyActionPerformWithActionArguments:args expectedFetchResult:UAActionFetchResultNoData];

    // Wait for it to complete
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    // Verify it was displayed
    [self.mockMessageCenter verify];
}

/**
 * Test the action performing without a message will fall back to displaying the
 * the default message center if no delegate is available.
 */
- (void)testPerformWithoutMessageFallsBackDefaultMessageCenter {
    // Set up the action arguments
    UAActionArguments *args = [UAActionArguments argumentsWithValue:nil withSituation:UASituationManualInvocation];

    // Should display in the default message center
    XCTestExpectation *expectation = [self expectationWithDescription:@"display called"];
    [[[self.mockMessageCenter expect] andDo:^(NSInvocation *invocation) {
        [expectation fulfill];
    }] display];
    // Need to stub a message list result so the action is able to finish
    [self stubMessageListRefreshWithSuccessBlock:nil];
    
    // Perform the action
    [self verifyActionPerformWithActionArguments:args expectedFetchResult:UAActionFetchResultNoData];

    // Wait for it to complete
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    // Verify it was displayed
    [self.mockMessageCenter verify];
}


#pragma mark -
#pragma mark Test helpers

- (void)verifyActionPerformWithActionArguments:(UAActionArguments *)args expectedFetchResult:(UAActionFetchResult)fetchResult{
    __block UAActionResult *actionResult = nil;

    [self.action performWithArguments:args completionHandler:^(UAActionResult *result) {
        actionResult = result;
        
        XCTAssertNotNil(actionResult, @"perform did not call the completion handler");
        XCTAssertNil(actionResult.value, @"action result value should be empty");
        XCTAssertEqual(fetchResult, actionResult.fetchResult, @"unexpected action fetch result");
    }];
}

- (void)stubMessageListRefreshWithSuccessBlock:(void (^)(void))block {
    [[self.mockMessageList stub] retrieveMessageListWithSuccessBlock:[OCMArg checkWithBlock:^BOOL(id obj) {
        if (block) {
            block();
        }
        UAInboxMessageListCallbackBlock callback = obj;
        if (callback) {
            callback();
        }
        return YES;
    }] withFailureBlock:OCMOCK_ANY];
}

- (void)stubMessageListRefreshWithFailureBlock:(void (^)(void))block {
    [[self.mockMessageList stub] retrieveMessageListWithSuccessBlock:OCMOCK_ANY
                                                      withFailureBlock:[OCMArg checkWithBlock:^BOOL(id obj) {

        if (block) {
            block();
        }
        UAInboxMessageListCallbackBlock callback = obj;
        if (callback) {
            callback();
        }
        return YES;
    }]];
}

@end
