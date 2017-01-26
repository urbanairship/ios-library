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

#import <XCTest/XCTest.h>
#import "UAInAppMessageController+Internal.h"
#import "UAInAppMessage.h"
#import "UAUtils.h"

#import "UAInAppMessageControllerDelegate.h"
#import "UAInAppMessageControllerDefaultDelegate.h"

#import "UAInAppMessageButtonActionBinding.h"


@interface UAInAppMessageControllerTest : XCTestCase

@property (nonatomic, strong) UAInAppMessage *message;
@property (nonatomic, strong) id mockMessageView;
@property (nonatomic, strong) id mockParentView;

@property (nonatomic, strong) id mockUserDelegate;
@property (nonatomic, strong) id mockDefaultDelegate;
@property (nonatomic, strong) id mockUtils;
@property (nonatomic, strong) id utilsParentView;

@property (nonatomic, strong) NSDictionary *payload;
@property (copy) void (^dismissalBlock)(UAInAppMessageController *controller);
@property (nonatomic, strong) UAInAppMessageController *testController;

@end

@implementation UAInAppMessageControllerTest

- (void)setUp {
    [super setUp];

    //Set up test message payload
    id expiry = @"2020-12-15T11:45:22";
    id extra = @{@"foo":@"bar", @"baz":@12345};

    id display = @{@"alert": @"hi!",
                   @"type": @"banner",
                   @"duration": @20,
                   @"position": @"top",
                   @"primary_color": @"#ffffffff",
                   @"secondary_color": @"#ff00ff00"};

    id actions = @{@"button_group": @"ua_yes_no_foreground",
                   @"button_actions": @{@"yes": @{@"^+t": @"yes_tag"},
                                        @"no": @{@"^+t": @"no_tag"}}};

    self.payload = @{@"identifier": @"some identifier",
                     @"expiry": expiry,
                     @"extra": extra,
                     @"display": display,
                     @"actions": actions};

    self.message = [UAInAppMessage messageWithPayload:self.payload];

    // Mock a message view for expecting calls
    self.mockMessageView = [OCMockObject niceMockForClass:[UIView class]];

    // Mock a parent view for expecting calls
    self.mockParentView = [OCMockObject niceMockForClass:[UIView class]];
    [[[self.mockMessageView stub] andReturn:self.mockParentView] superview];

    // Make the parent view returned by UAUtils configurable
    self.utilsParentView = self.mockParentView;
    self.mockUtils = [OCMockObject niceMockForClass:[UAUtils class]];
    [[[self.mockUtils stub] andDo:^(NSInvocation *invocation) {
        [invocation setReturnValue:&_utilsParentView];
    }] mainWindow];

    // Mock default delegate protocol
    self.mockDefaultDelegate = [OCMockObject niceMockForClass:[UAInAppMessageControllerDefaultDelegate class]];
    [[[self.mockDefaultDelegate stub] andReturn:self.mockMessageView] viewForMessage:OCMOCK_ANY parentView:OCMOCK_ANY];

    // Mock user delegate protocol
    self.mockUserDelegate = [OCMockObject niceMockForProtocol:@protocol(UAInAppMessageControllerDelegate)];
    [[[self.mockUserDelegate stub] andReturn:self.mockMessageView] viewForMessage:OCMOCK_ANY parentView:OCMOCK_ANY];

    // Initialize a testController set mockedUserDelegate as default delegate
    self.testController = [UAInAppMessageController controllerWithMessage:self.message
                                                                 delegate:self.mockUserDelegate
                                                           dismissalBlock:self.dismissalBlock];

    self.testController.defaultDelegate = self.mockDefaultDelegate;
}

- (void)tearDown {
    [self.mockUserDelegate stopMocking];
    [self.mockDefaultDelegate stopMocking];
    [self.mockMessageView stopMocking];
    [self.mockParentView stopMocking];
    [self.mockUtils stopMocking];

    [super tearDown];
}

/**
* Tests in app message controller initialization
*/
- (void)testControllerWithMessage {
    XCTAssertEqualObjects(self.message, self.testController.message, @"The view controller's message property should match the message it was initialized with.");
    XCTAssertEqualObjects(self.message.buttonActionBindings, self.testController.message.buttonActionBindings, @"Button action bindings should match.");
    XCTAssertEqualObjects(self.mockUserDelegate, self.testController.userDelegate, @"User delegates should match.");
}

/**
 * Test early return when message is already shown
 */
- (void)testShowAlreadyShown {
    XCTAssertTrue([self.testController show]);
    XCTAssertFalse([self.testController show]);
}

/**
 * Test show when parent view is nil
 */
- (void)testShowParentViewIsNil {
    self.utilsParentView = nil;
    XCTAssertFalse([self.testController show], @"Should not show controller when parent view is nil.");
}

/**
 * Test show with the user delegate when message has no onClick actions
 */
- (void)testShowWithUserDelegateNoOnClickActions {
    // Setup
    [self setUserDelegateShowExpectations];

    // Since onClick == nil, expect gesture recognizer add only on parent view
    [[self.mockParentView expect] addGestureRecognizer:[OCMArg checkWithSelector:@selector(checkPanGestureRecognizer:) onObject:self]];

    // Display the in-app message
    [self.testController show];

    [self.mockUserDelegate verify];
    [self.mockParentView verify];
}

/**
 * Test show with the default delegate when message has no onClick actions
 */
- (void)testShowWithDefaultDelegateNoOnClickAction {
    // Setup
    [self setUserDelegateShowExpectations];

    // Since onClick == nil expect gesture recognizer add only on parent view
    [[self.mockParentView expect] addGestureRecognizer:[OCMArg checkWithSelector:@selector(checkPanGestureRecognizer:) onObject:self]];

    // Show the in-app message
    [self.testController show];

    [self.mockDefaultDelegate verify];
    [self.mockParentView verify];

}

/**
 * Test show with the user delegate when message has onClick actions
 */
- (void)testShowWithUserDelegateOnClickActions {
    // Setup
    [self setUserDelegateShowExpectations];

    // Add onClick action to message
    self.testController.message.onClick = @{@"^d":@"http://google.com"};

    // Since onClick != nil expect gesture recognizer add on both parent and message view
    // Expect addition of a UITapGestureRecognizer to parent view
    [[self.mockParentView expect] addGestureRecognizer:[OCMArg checkWithSelector:@selector(checkPanGestureRecognizer:) onObject:self]];

    // Expect addition of a UITapGestureRecognizer to message view
    [[self.mockMessageView expect] addGestureRecognizer:OCMOCK_ANY];

    // Expect addition of a UILongPressGestureRecognizer message view
    [[self.mockMessageView expect] addGestureRecognizer:OCMOCK_ANY];

    // Mock user delegate will inject the mockMessageView when the userDelegate is not nil
    [[[self.mockUserDelegate stub] andReturn:self.mockMessageView] viewForMessage:self.testController.message parentView:self.mockParentView];

    // Show the in-app message
    [self.testController show];

    [self.mockUserDelegate verify];
    [self.mockMessageView verify];
    [self.mockParentView verify];
}

/**
 * Test show with the default delegate when message has onClick actions
 */
- (void)testShowWithDefaultDelegateOnClickActions {

    [self setUpDefaultDelegateShowExpectations];

    // Add onClick action to message
    self.testController.message.onClick = @{@"^d":@"http://google.com"};

    // Since onClick != nil expect gesture recognizer add on both parent and message view
    // Expect addition of a UITapGestureRecognizer to parent view
    [[self.mockParentView expect] addGestureRecognizer:[OCMArg checkWithSelector:@selector(checkPanGestureRecognizer:) onObject:self]];

    // Expect addition of a UITapGestureRecognizer to message view
    [[self.mockMessageView expect] addGestureRecognizer:OCMOCK_ANY];

    // Expect addition of a UILongPressGestureRecognizer message view
    [[self.mockMessageView expect] addGestureRecognizer:OCMOCK_ANY];

    [self.testController show];

    [self.mockDefaultDelegate verify];
    [self.mockMessageView verify];
    [self.mockParentView verify];
}

/**
 * Test dismiss with user delegate
 */
- (void)testDismissWithUserDelegate {
    // Display the in-app message
    [self.testController show];

    // Properly return parent view when superview is called on mockMessageView
    [[[self.mockMessageView stub] andReturn:self.mockParentView] superview];

    // Ensure gestures are disabled
    [[self.mockMessageView expect] setUserInteractionEnabled:NO];
    [[self.mockParentView expect] removeGestureRecognizer:OCMOCK_ANY];

    // Set up animate out expectation
    XCTestExpectation *testExpectation = [self expectationWithDescription:@"User delegate dismiss finished."];

    // Properly return parent view when superview is called on mockMessageView
    [[[self.mockMessageView stub] andReturn:self.mockParentView] superview];

    // Ensure that the mockUserDelegate gets called to animate out
    [[[self.mockUserDelegate stub] andDo:^(NSInvocation *invocation) {
        [testExpectation fulfill];
    }] messageView:self.mockMessageView animateOutWithParentView:self.mockParentView completionHandler:OCMOCK_ANY];

    [self.testController dismiss];
    [self waitForExpectationsWithTimeout:5 handler:^(NSError *error){
        if (error) {
            XCTFail(@"Failed to animate out message view with error: %@.", error);
        }
    }];

    // Verify teardown expectations
    [self.mockMessageView verify];
    [self.mockParentView verify];
}

/**
 * Test dismiss with default delegate
 */
- (void)testDismissWithDefaultDelegate {
    // Set userDelegate to nil so default delegate is used
    self.testController.userDelegate = nil;

    // Set up animate out expectation
    XCTestExpectation *testExpectation = [self expectationWithDescription:@"Default delegate dismiss finished."];

    // Display the in-app message
    [self.testController show];

    // Dismissing should remove gestures and set user interaction to NO
    [[self.mockMessageView expect] setUserInteractionEnabled:NO];
    [[self.mockParentView expect] removeGestureRecognizer:OCMOCK_ANY];

    // Ensure that the mockUserDelegate gets called to animate out
    [[[self.mockDefaultDelegate stub] andDo:^(NSInvocation *invocation) {
        [testExpectation fulfill];
    }] messageView:OCMOCK_ANY animateOutWithParentView:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    // Dismiss the in-app message
    [self.testController dismiss];

    // Wait for the animate out to finish
    [self waitForExpectationsWithTimeout:5 handler:^(NSError *error){
        if (error) {
            XCTFail(@"Failed to animate out message view with error: %@.", error);
            return;
        }
    }];

    // Verify teardown expectations
    [self.mockMessageView verify];
    [self.mockParentView verify];
}

// Helper methods

/**
 * Checks that the pan gesture recognizer has been added and properly configured
 */
- (BOOL)checkPanGestureRecognizer:(id)value {
    UIPanGestureRecognizer *gesture = value;
    if (gesture.delaysTouchesBegan || gesture.delaysTouchesEnded || gesture.cancelsTouchesInView) {
        return NO;
    }

    return YES;
}

/**
 * Expects that the pan gesture recognizer has been set and properly configured
 */
- (void)expectPanGestureRecognizerSetup {
    [[self.mockParentView expect] addGestureRecognizer:[OCMArg checkWithBlock:^BOOL(id value) {
        return [self checkPanGestureRecognizer:value];
    }]];
}

/**
 * Sets up expectations for testing when userDelegate is not nil
 */
-(void)setUserDelegateShowExpectations {
    // Expect button clicks at index zeroth and first index
    [[self.mockUserDelegate expect] messageView:OCMOCK_ANY buttonAtIndex:0];
    [[self.mockUserDelegate expect] messageView:OCMOCK_ANY buttonAtIndex:1];

    // Expect call to animate in
    [[self.mockUserDelegate expect] messageView:OCMOCK_ANY animateInWithParentView:self.mockParentView completionHandler:OCMOCK_ANY];
}

/**
 * Sets up expectations for testing when userDelegate is nil
 */
-(void)setUpDefaultDelegateShowExpectations {
    // Inject the mock message view when viewForMessage is called on parent view
    [[[self.mockDefaultDelegate stub] andReturn:self.mockMessageView] viewForMessage:self.testController.message parentView:self.mockParentView];

    // Expect calls to buttonsAtIndex at index zeroth and first index
    [[self.mockDefaultDelegate expect] messageView:OCMOCK_ANY buttonAtIndex:0];
    [[self.mockDefaultDelegate expect] messageView:OCMOCK_ANY buttonAtIndex:1];

    [[self.mockDefaultDelegate expect] messageView:self.mockMessageView animateInWithParentView:self.mockParentView completionHandler:OCMOCK_ANY];

    self.testController.userDelegate = nil;
}

@end
