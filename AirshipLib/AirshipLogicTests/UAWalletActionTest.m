/*
 Copyright 2009-2016 Urban Airship Inc. All rights reserved.

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
#import <Foundation/Foundation.h>

#import "UAActionArguments+Internal.h"
#import "UAWalletAction+Internal.h"
#import "UAHTTPRequest+Internal.h"

@interface UAWalletActionTest : XCTestCase

@property (nonatomic, strong) UAActionArguments *arguments;
@property (nonatomic, strong) UAWalletAction *action;

@end

@implementation UAWalletActionTest

- (void)setUp {
    [super setUp];

    self.arguments = [[UAActionArguments alloc] init];

    self.action = [[UAWalletAction alloc] init];

}

/**
 * Test accepts valid string arguments.
 */
- (void)testAcceptsArguments {
    // Mock the PKPassLibrary availability
    id mockPassLibrary = [OCMockObject niceMockForClass:[PKPassLibrary class]];
    [[[mockPassLibrary stub] andReturnValue:OCMOCK_VALUE(YES)] isPassLibraryAvailable];

    self.arguments.value = @"a valid string";

    UASituation validSituations[6] = {
        UASituationForegroundPush,
        UASituationForegroundInteractiveButton,
        UASituationLaunchedFromPush,
        UASituationManualInvocation,
        UASituationWebViewInvocation,
        UASituationBackgroundPush
    };

    for (int i = 0; i < 5; i++) {
        self.arguments.situation = validSituations[i];
        XCTAssertTrue([self.action acceptsArguments:self.arguments], @"action should accept valid string URLs");
    }

}

/**
 * Test rejects all arguments when pass library not present.
 */
- (void)testAcceptsArgumentsRejectsWhenPassLibraryNotPresent {
    // Mock the PKPassLibrary availability
    id mockPassLibrary = [OCMockObject niceMockForClass:[PKPassLibrary class]];
    [[[mockPassLibrary stub] andReturnValue:OCMOCK_VALUE(NO)] isPassLibraryAvailable];

    UAWalletAction *walletAction = [[UAWalletAction alloc] init];

    UAActionArguments *args = [UAActionArguments argumentsWithValue:@"a string"
                                                      withSituation:UASituationManualInvocation];

    XCTAssertFalse([walletAction acceptsArguments:args], @"Should not be able to register a wallet action on a device without PKPassLibrary.");

    [mockPassLibrary stopMocking];
}

/**
 * Test rejects duplicate pass add.
 */
- (void)testRejectsDuplicatePass {
    __block BOOL completionBlockCalled = NO;

    // Stub the connectionWithRequest:successBlock:failureBlock: and capture the success block
    __block UAHTTPConnectionSuccessBlock successBlock;
    id mockConnection = [OCMockObject niceMockForClass:[UAHTTPConnection class]];
    [[mockConnection stub] connectionWithRequest:OCMOCK_ANY successBlock:[OCMArg checkWithBlock:^BOOL(id obj) {
        successBlock = obj;
        return YES;
    }] failureBlock:OCMOCK_ANY];

    // Mock the PKPassLibrary availability
    id mockPassLibrary = [OCMockObject niceMockForClass:[PKPassLibrary class]];
    [[[mockPassLibrary stub] andReturnValue:OCMOCK_VALUE(YES)] isPassLibraryAvailable];
    [[[mockPassLibrary stub] andReturnValue:OCMOCK_VALUE(YES)] containsPass:OCMOCK_ANY];

    // Mock the PKPass to avoid early error return
    id mockPass = [OCMockObject niceMockForClass:[PKPass class]];
    [[[mockPass stub] andReturn:mockPass] alloc];
    // Silence expression result unused warning by casting to void
    (void)[[[mockPass stub] andReturn:mockPass] initWithData:OCMOCK_ANY error:[OCMArg setTo:nil]];

    UAWalletAction *walletAction = [[UAWalletAction alloc] init];
    walletAction.passLibrary = mockPassLibrary;

    UAActionArguments *args = [UAActionArguments argumentsWithValue:@"a string" withSituation:UASituationManualInvocation];

    [walletAction performWithArguments:args completionHandler:^(UAActionResult *result) {
        XCTAssertEqual(UAActionFetchResultNewData, result.fetchResult,
                       @"An attempt to add a duplicate pass should result in UAActionFetchResultNewData.");

        completionBlockCalled = YES;
    }];

    // Call the success block with a 200
    UAHTTPRequest *request = [[UAHTTPRequest alloc] init];
    request.response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:nil];

    request.responseData = [NSData data];
    
    successBlock(request);

    XCTAssertTrue(completionBlockCalled);

    [mockPassLibrary stopMocking];
    [mockPass stopMocking];
    [mockConnection stopMocking];
}

/**
 * Test accepts arguments rejects background interactive button situations.
 */
- (void)testAcceptsArgumentsRejectsBackgroundInteractiveButtonSituations {
    self.arguments.value = @"a valid string url";

    self.arguments.situation = UASituationBackgroundInteractiveButton;
    XCTAssertFalse([self.action acceptsArguments:self.arguments], @"action should reject situation UASituationBackgroundInteractiveButton");
}

/**
 * Test rejects argument values that are not strings.
 */
- (void)testAcceptsArgumentsRejectsNonStrings {
    self.arguments.situation = UASituationForegroundPush;

    self.arguments.value = nil;
    XCTAssertFalse([self.action acceptsArguments:self.arguments], @"action should not accept a nil value");

    self.arguments.value = @3213;
    XCTAssertFalse([self.action acceptsArguments:self.arguments], @"action should not accept non strings");
}

@end
