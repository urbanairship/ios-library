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
    XCTAssertEqual(blockArgs, self.emptyArgs, @"Base acceptsArgumentBlock should have the same arguments paramater as acceptsArguments");

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
    XCTAssertEqual(blockArgs, self.emptyArgs, @"performWithArgumnts block should be passed the same arguments performWithArguments:withCompletionHandler:");
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
}

/**
 * Test that the continueWith operator
 */
- (void)testContinueWith {
    __block BOOL didContinuationActionRun = NO;
    __block UAActionResult *result;
    __block UAActionArguments *continuationArguments;

    UAAction *action = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
        return completionHandler([UAActionResult resultWithValue:@"originalResult"]);
    }];

    UAAction *continuationAction = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
        continuationArguments = args;
        return completionHandler([UAActionResult resultWithValue:@"continuationResult"]);
    }];

    continuationAction.onRunBlock = ^{
        didContinuationActionRun = YES;
    };

    action = [action continueWith:continuationAction];
    [action runWithArguments:self.emptyArgs withCompletionHandler:^(UAActionResult *actionResult){
        result = actionResult;
    }];


    XCTAssertTrue(didContinuationActionRun, @"The continuation action should be run if the original action does not return an error.");
    XCTAssertEqualObjects(continuationArguments.value, @"originalResult", @"The continuation action should be passed a new argument with the value of the previous result");
    XCTAssertEqualObjects(result.value, @"continuationResult", @"Running a continuation action should call completion handler with the result from the continuation action");
}

/**
 * Test that the continueWith does not call the continuationAction if the original
 * action returns an error result
 */
- (void)testContinueWithError {
    __block BOOL didContinuationActionRun = NO;
    __block UAActionResult *result;

    UAActionResult *errorResult = [UAActionResult error:[NSError errorWithDomain:@"some-domian" code:10 userInfo:nil]];


    // Set up action to return an error result
    UAAction *action = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
        return completionHandler(errorResult);
    }];

    UAAction *continuationAction = [[UAAction alloc] init];
    continuationAction.onRunBlock = ^{
        didContinuationActionRun = YES;
    };

    action = [action continueWith:continuationAction];
    [action runWithArguments:self.emptyArgs withCompletionHandler:^(UAActionResult *actionResult){
        result = actionResult;
    }];

    XCTAssertFalse(didContinuationActionRun, @"The continuation action should not run if the action original action returns an error.");
    XCTAssertEqual(result, errorResult, @"Completion handler should be called with the original result if the continuation action is not called.");
}

/**
 * Test continueWith when passing a nil continuation action
 */
- (void)testContinueWithNilAction {
    __block UAActionResult *result;

    UAAction *action = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
        return completionHandler([UAActionResult resultWithValue:@"originalResult"]);
    }];


    action = [action continueWith:nil];
    [action runWithArguments:self.emptyArgs withCompletionHandler:^(UAActionResult *actionResult){
        result = actionResult;
    }];

    XCTAssertEqualObjects(result.value, @"originalResult", @"Continue with should ignore a nil continue with action and just return the original actions result");
}

/**
 * Tests the skip operator
 */
- (void)testSkip {
    __block int performCount = 0;
    __block UAActionResult *expectedResult = [UAActionResult resultWithValue:@"some-value"];

    UAAction *action = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
        performCount++;
        return completionHandler(expectedResult);
    }];

    UAAction *skipAction = [action skip:10];

    // Run the skip action 10 times, should skip each time
    for (int i = 0; i < 10; i++) {
        [skipAction runWithArguments:self.emptyArgs withCompletionHandler:^(UAActionResult *result) {}];
    }

    XCTAssertEqual(0, performCount, @"Skip is not skipping");

    // Run it 10 more times
    for (int i = 0; i < 10; i++) {
        [skipAction runWithArguments:self.emptyArgs withCompletionHandler:^(UAActionResult *result) {
            XCTAssertEqualObjects(result, expectedResult, @"Skip result is unexpected");
        }];
    }

    XCTAssertEqual(10, performCount, @"Skip should stop skipping after it skipped the n number of times.");
}

/**
 * Tests the skip operator does not skip if you try to skip 0 times
 */
- (void)testSkipZeroTimes {
    __block int performCount = 0;

    UAAction *action = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
        performCount++;
        return completionHandler([UAActionResult none]);
    }];

    UAAction *skipAction = [action skip:0];

    // Run the skip action 10 times, should skip each time
    for (int i = 0; i < 10; i++) {
        [skipAction runWithArguments:self.emptyArgs withCompletionHandler:^(UAActionResult *result) {}];
    }

    XCTAssertEqual(10, performCount, @"Skip should not skip if its told to skip 0 times");
}

/**
 * Tests the take operator
 */
- (void)testTake {
    __block int performCount = 0;
    __block UAActionResult *expectedResult = [UAActionResult resultWithValue:@"some-value"];

    UAAction *action = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
        performCount++;
        return completionHandler(expectedResult);
    }];

    UAAction *takeAction = [action take:10];

    // Run the take action 10 times, should skip each time
    for (int i = 0; i < 10; i++) {
        [takeAction runWithArguments:self.emptyArgs withCompletionHandler:^(UAActionResult *result) {
            XCTAssertEqualObjects(result, expectedResult, @"Take result is unexpected");
        }];
    }

    XCTAssertEqual(10, performCount, @"Take is not taking");

    // Run it 10 more times
    for (int i = 0; i < 10; i++) {
        [takeAction runWithArguments:self.emptyArgs withCompletionHandler:^(UAActionResult *result) {}];
    }

    XCTAssertEqual(10, performCount, @"Take should stop taking after it took for the n number of times");
}

/**
 * Tests the take operator never takes if you try to take 0 times
 */
- (void)testTakeZeroTimes {
    __block int performCount = 0;

    UAAction *action = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
        performCount++;
        return completionHandler([UAActionResult none]);
    }];

    UAAction *takeAction = [action take:0];

    // Run the take action 10 times
    for (int i = 0; i < 10; i++) {
        [takeAction runWithArguments:self.emptyArgs withCompletionHandler:^(UAActionResult *result) {}];
    }

    XCTAssertEqual(0, performCount, @"Take should not take if its told to take 0 times");
}

/**
 * Tests the nth operator
 */
- (void)testNth {
    __block int performCount = 0;
    __block UAActionResult *expectedResult = [UAActionResult resultWithValue:@"some-value"];

    UAAction *action = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
        performCount++;
        return completionHandler(expectedResult);
    }];

    UAAction *nthAction = [action nth:10];

    // Run the nth action 9 times, should skip
    for (int i = 0; i < 9; i++) {
        [nthAction runWithArguments:self.emptyArgs withCompletionHandler:^(UAActionResult *result) {}];
    }

    XCTAssertEqual(0, performCount, @"Nth should only run on the nth run");

    // Should perform on next run
    [nthAction runWithArguments:self.emptyArgs withCompletionHandler:^(UAActionResult *result) {
        XCTAssertEqualObjects(result, expectedResult, @"Nth result is unexpected");
    }];

    XCTAssertEqual(1, performCount, @"Nth did not run on the nth run");

    // Run it 10 more times, should skip the rest
    for (int i = 0; i < 10; i++) {
        [nthAction runWithArguments:self.emptyArgs withCompletionHandler:^(UAActionResult *result) {}];
    }

    XCTAssertEqual(1, performCount, @"Nth should only run once.");
}

/**
 * Tests the nth operator never runs if n = 0
 */
- (void)testNthOnZero {
    __block int performCount = 0;

    UAAction *action = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
        performCount++;
        return completionHandler([UAActionResult none]);
    }];

    UAAction *nthAction = [action nth:0];

    // Run the skip action 10 times, should skip each time
    for (int i = 0; i < 10; i++) {
        [nthAction runWithArguments:self.emptyArgs withCompletionHandler:^(UAActionResult *result) {}];
    }

    XCTAssertEqual(0, performCount, @"nth should never run on the 0 case");
}


@end
