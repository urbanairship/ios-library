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

#import <XCTest/XCTest.h>
#import "UAAction+Internal.h"

@interface UAActionTest : XCTestCase
@property (nonatomic, strong) UAActionArguments *emptyArgs;
@end

@implementation UAActionTest

- (void)setUp {
    self.emptyArgs = [UAActionArguments argumentsWithValue:nil withSituation:UASituationManualInvocation];
    [super setUp];
}

/*
 * Tests that the default implementation of acceptsArguments always returns YES
 */
- (void)testAcceptsArguments {
    UAAction *action = [[UAAction alloc] init];
    XCTAssertTrue([action acceptsArguments:[UAActionArguments argumentsWithValue:nil withSituation:UASituationManualInvocation]], @"Base UAAction should accept all arguments.");
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
    XCTAssertEqualObjects(blockArgs, self.emptyArgs, @"Base acceptsArgumentBlock should have the same arguments parameter as acceptsArguments");

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
    [action performWithArguments:self.emptyArgs completionHandler:^(UAActionResult *result) {
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
    [action performWithArguments:self.emptyArgs completionHandler:^(UAActionResult *result) {
        blockResult = result;
    }];

    XCTAssertEqualObjects(blockResult.value, @"hi", @"performWithArguments:withCompletionHandler: should call the actionBlock");
    XCTAssertEqual(blockResult.fetchResult, UAActionFetchResultNewData, @"performWithArguments:withCompletionHandler: should call the actionBlock");
    XCTAssertEqualObjects(blockArgs, self.emptyArgs, @"performWithArguments block should be passed the same arguments performWithArguments:withCompletionHandler:");
}

/*
 * Test running an action when the action accepts the arguments
 */
- (void)testRunWithArguments {
    __block UAActionArguments *blockPerformArgs;
    __block UAActionArguments *blockAcceptsArgs;
    __block UAActionResult *blockResult;


    UAAction *action = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
        blockPerformArgs = args;
        completionHandler([UAActionResult resultWithValue:@"hi" withFetchResult:UAActionFetchResultNewData]);
    }];

    action.acceptsArgumentsBlock = ^(UAActionArguments *args) {
        blockAcceptsArgs = args;
        return YES;
    };

    [action runWithArguments:self.emptyArgs completionHandler:^(UAActionResult *actionResult) {
        blockResult = actionResult;
    }];

    XCTAssertEqualObjects(blockResult.value, @"hi", @"runWithArguments:withCompletionHandler: did not return the result defined by the action");
    XCTAssertEqual(blockResult.fetchResult, UAActionFetchResultNewData, @"runWithArguments:withCompletionHandler: did not return the result defined by the action");
    XCTAssertEqualObjects(blockPerformArgs, self.emptyArgs, @"runWithArguments:withCompletionHandler: is not passing in the run arguments to the actions performWithArguments:withCompletionHandler:");
    XCTAssertEqualObjects(blockAcceptsArgs, self.emptyArgs, @"runWithArguments:withCompletionHandler: is not passing in the run arguments to the actions acceptsArguments:");
}

/*
 * Test that running the action from a background thread will result in
 * the action being performed on the UI thread.
 */
- (void)testRunOnBackgroundThread {
    XCTestExpectation *testExpectation = [self expectationWithDescription:@"action finished"];

    BOOL (^isMainThread)(void) = ^{
        return [[NSThread currentThread] isEqual:[NSThread mainThread]];
    };

    UAAction *action = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler handler) {
        XCTAssertTrue(isMainThread(), @"we should be on the main thread");
        handler([UAActionResult emptyResult]);
    }];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        XCTAssertFalse(isMainThread(), @"we should be on a background thread");
        [action runWithArguments:[UAActionArguments argumentsWithValue:nil withSituation:UASituationManualInvocation]
               completionHandler:^(UAActionResult *result) {
            XCTAssertTrue(isMainThread(), @"we should be on the main thread");
            [testExpectation fulfill];
        }];
    });

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

/*
 * Test that calling the completion handler on a background thread will result in
 * the work being marshalled back onto the main thread.
 */
- (void)testFinishOnBackgroundThread {
    XCTestExpectation *testExpectation = [self expectationWithDescription:@"action finished"];

    BOOL (^isMainThread)(void) = ^{
        return [[NSThread currentThread] isEqual:[NSThread mainThread]];
    };

    UAAction *action = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler handler) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            XCTAssertFalse(isMainThread(), @"we should be on a background thread");
            handler([UAActionResult emptyResult]);
        });
    }];

    [action runWithArguments:[UAActionArguments argumentsWithValue:nil withSituation:UASituationManualInvocation]
           completionHandler:^(UAActionResult *result) {
        XCTAssertTrue(isMainThread(), @"we should be back on the main thread");
        [testExpectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

/*
 * Test running an action when the action does not accept the arguments
 */
- (void)testRunWithArgumentsInvalidActionArguments {
    __block UAActionResult *blockResult;

    UAAction *action = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
        XCTFail(@"performWithArguments:withCompletionHandler: should not be called if the action cannot accept the arguments");
        return completionHandler([UAActionResult emptyResult]);
    }];

    action.acceptsArgumentsBlock = ^(UAActionArguments *args) {
        return NO;
    };

    [action runWithArguments:self.emptyArgs completionHandler:^(UAActionResult *actionResult) {
        blockResult = actionResult;
    }];

    XCTAssertNil(blockResult.value, @"runWithArguments:withCompletionHandler: should default to calling completion handler with a nil value");
    XCTAssertEqual(blockResult.fetchResult, UAActionFetchResultNoData, @"runWithArguments:withCompletionHandler: should default to calling completion handler with UAActionFetchResultNoData");
    XCTAssertEqual(blockResult.status, UAActionStatusArgumentsRejected, @"runWithArguments:withCompletionHandler: should default to calling completion handler with a rejected arguments result");
}

@end
