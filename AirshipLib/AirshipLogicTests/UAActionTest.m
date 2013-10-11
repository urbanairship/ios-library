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
#import "UAAction+Internal.h"

@interface UAActionTest : XCTestCase
@property (nonatomic, strong)UAActionArguments *emptyArgs;
@end

@implementation UAActionTest

- (void)setUp {
    self.emptyArgs = [UAActionArguments argumentsWithValue:nil withSituation:nil];

    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

/*
 * Tests that the default implementation of acceptsArguments always returns YES
 */
- (void)testAcceptsArguments {
    UAAction *action = [[UAAction alloc] init];
    XCTAssertTrue([action acceptsArguments:[UAActionArguments argumentsWithValue:nil withSituation:nil]], @"Base UAAction should accept all arguments.");
}

/*
 * Tests that the default implementation of acceptsArguments returns the 
 * action's acceptsArgumentsBlock result if defined
 */
- (void)testAcceptsArgumentsBlock {
    UAAction *action = [[UAAction alloc] init];

    __block UAActionArguments *blockArgs;
    action.acceptsArgumentsBlock = ^(UAActionArguments *args) {
        blockArgs = args;
        return NO;
    };

    XCTAssertFalse([action acceptsArguments:self.emptyArgs], @"Base UAAction should return the acceptsArgumentsBlock if defined");
    XCTAssertEqual(blockArgs, self.emptyArgs, @"Base acceptsArgumentBlock should have the same arguments parameter as acceptsArguments");

    action.acceptsArgumentsBlock = ^(UAActionArguments *args) {
        return YES;
    };

    XCTAssertTrue([action acceptsArguments:self.emptyArgs], @"Base UAAction should return the acceptsArgumentsBlock result if defined");
}

/*
 * Test perform with arguments always calls the completion handler with a
 * empty result
 */
- (void)testPerformWithArguments {
    UAAction *action = [[UAAction alloc] init];

    __block UAActionResult *blockResult;
    [action performWithArguments:self.emptyArgs withCompletionHandler:^(UAActionResult *result) {
        blockResult = result;
    }];

    XCTAssertNil(blockResult.value, @"performWithArguments:withCompletionHandler: should default to calling completion handler with a nil value");
    XCTAssertEqual(blockResult.fetchResult, UAActionFetchResultNoData, @"performWithArguments:withCompletionHandler: should default to calling completion handler with UAActionFetchResultNoData");
}

/*
 * Test perform with arguments calls the actionBlock if defined
 */
- (void)testPerformWithArgumentsBlock {

    __block UAActionArguments *blockArgs;

    UAAction *action = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
        blockArgs = args;
        return completionHandler([UAActionResult resultWithValue:@"hi" withFetchResult:UAActionFetchResultNewData]);
    }];

    __block UAActionResult *blockResult;
    [action performWithArguments:self.emptyArgs withCompletionHandler:^(UAActionResult *result) {
        blockResult = result;
    }];

    XCTAssertEqualObjects(blockResult.value, @"hi", @"performWithArguments:withCompletionHandler: should call the actionBlock");
    XCTAssertEqual(blockResult.fetchResult, UAActionFetchResultNewData, @"performWithArguments:withCompletionHandler: should call the actionBlock");
    XCTAssertEqual(blockArgs, self.emptyArgs, @"performWithArguments block should be passed the same arguments performWithArguments:withCompletionHandler:");
}

/*
 * Test running an action when the action accepts the arguments
 */
- (void)testRunWithArguments {
    __block UAActionArguments *blockPerformArgs;
    __block UAActionArguments *blockAcceptsArgs;
    __block UAActionResult *blockResult;
    __block BOOL onRunBlockRan = NO;

    UAAction *action = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
        blockPerformArgs = args;
        return completionHandler([UAActionResult resultWithValue:@"hi" withFetchResult:UAActionFetchResultNewData]);
    }];

    action.acceptsArgumentsBlock = ^(UAActionArguments *args) {
        blockAcceptsArgs = args;
        return YES;
    };

    action.onRunBlock = ^{
        onRunBlockRan = YES;
    };

    [action runWithArguments:self.emptyArgs withCompletionHandler:^(UAActionResult *actionResult) {
        blockResult = actionResult;
    }];


    XCTAssertEqualObjects(blockResult.value, @"hi", @"runWithArguments:withCompletionHandler: did not return the result defined by the action");
    XCTAssertEqual(blockResult.fetchResult, UAActionFetchResultNewData, @"runWithArguments:withCompletionHandler: did not return the result defined by the action");
    XCTAssertEqual(blockPerformArgs, self.emptyArgs, @"runWithArguments:withCompletionHandler: is not passing in the run arguments to the actions performWithArguments:withCompletionHandler:");
    XCTAssertEqual(blockAcceptsArgs, self.emptyArgs, @"runWithArguments:withCompletionHandler: is not passing in the run arguments to the actions acceptsArguments:");
    XCTAssertTrue(onRunBlockRan, @"onRunBlock is not being called");
}

/*
 * Test running an action when the action does not accept the arguments
 */
- (void)testRunWithArgumentsInvalidActionArguments {
    __block BOOL onRunBlockRan = NO;
    __block UAActionResult *blockResult;

    UAAction *action = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
        XCTFail(@"performWithArguments:withCompletionHandler: should not be called if the action cannot accept the arguments");
        return completionHandler([UAActionResult none]);
    }];

    action.acceptsArgumentsBlock = ^(UAActionArguments *args) {
        return NO;
    };

    action.onRunBlock = ^{
        onRunBlockRan = YES;
    };

    [action runWithArguments:self.emptyArgs withCompletionHandler:^(UAActionResult *actionResult) {
        blockResult = actionResult;
    }];


    XCTAssertNil(blockResult.value, @"runWithArguments:withCompletionHandler: should default to calling completion handler with a nil value");
    XCTAssertEqual(blockResult.fetchResult, UAActionFetchResultNoData, @"runWithArguments:withCompletionHandler: should default to calling completion handler with UAActionFetchResultNoData");

    XCTAssertTrue(onRunBlockRan, @"onRunBlock should still be called even if the action is unable to accept the arguments");

    XCTAssertNotNil(blockResult.error, @"runWithArguments:withCompletionHandler: should default to calling completion handler with an error");
}

@end
