/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.

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
#import "UAWebInvocationActionArguments.h"
#import "UACloseWindowAction.h"
#import <OCMock/OCMock.h>
#import "UARichContentWindow.h"


@interface UACloseWindowActionTest : XCTestCase
@property(nonatomic, strong)id mockWebView;
@property(nonatomic, strong)id mockUARichContentWindow;
@property(nonatomic, strong)UACloseWindowAction *action;
@end

@implementation UACloseWindowActionTest

- (void)setUp {
    [super setUp];

    self.action = [[UACloseWindowAction alloc] init];

    self.mockUARichContentWindow = [OCMockObject niceMockForProtocol:@protocol(UARichContentWindow)];

    self.mockWebView = [OCMockObject niceMockForClass:[UIWebView class]];
    [[[self.mockWebView stub] andReturn:self.mockUARichContentWindow] delegate];
}

- (void)tearDown{
    [self.mockWebView stopMocking];
    [self.mockUARichContentWindow stopMocking];
    [super tearDown];
}

/**
 * Test the action accepts UASituationWebViewInvocation and UAWebInvocationActionArguments
 */
- (void)testAcceptsArguments {
    
    NSDictionary *metadata = [[NSDictionary alloc] initWithObjectsAndKeys:self.mockWebView, UAWebViewMetadataKey, nil];
    
    UAActionArguments *args = [UAActionArguments argumentsWithValue:nil  withSituation:UASituationWebViewInvocation andMetadata:metadata];
    XCTAssertTrue([self.action acceptsArguments:args], @"Close window action should accept any UAWebInvocationActionArguments with situation UASituationWebViewInvocation.");

    args.situation = UASituationManualInvocation;
    XCTAssertFalse([self.action acceptsArguments:args], @"Close window action should not accept UASituationManualInvocation.");

    args = [UAActionArguments argumentsWithValue:@"blah" withSituation:UASituationWebViewInvocation];
    XCTAssertFalse([self.action acceptsArguments:args], @"Close window action should not accept standard UAActionArguments.");
}

/**
 * Test actions perform
 */
- (void)testPerform {
    
    NSDictionary *metadata = [[NSDictionary alloc] initWithObjectsAndKeys:self.mockWebView, UAWebViewMetadataKey, nil];

    UAActionArguments *args = [UAActionArguments argumentsWithValue:nil  withSituation:UASituationWebViewInvocation andMetadata:metadata];

    [[self.mockUARichContentWindow expect] closeWindow:YES];

    __block id actionResult;

    [self.action performWithArguments:args withCompletionHandler:^(UAActionResult *result){
        actionResult = result;
    }];

    XCTAssertNotNil(actionResult, @"Completion handler should be called with an empty result");
    XCTAssertNoThrow([self.mockUARichContentWindow verify], @"The delegate's close method should be called");
}

/**
 * Test actions perform
 */
- (void)testPerformNilWebView {
    
    UAActionArguments *args = [UAActionArguments argumentsWithValue:nil  withSituation:UASituationWebViewInvocation andMetadata:nil];

    __block id actionResult;

    [self.action performWithArguments:args withCompletionHandler:^(UAActionResult *result){
        actionResult = result;
    }];

    XCTAssertNotNil(actionResult, @"Completion handler should be called with an empty result");
}

@end
