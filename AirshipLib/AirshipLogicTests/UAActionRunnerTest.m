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
#import "UAAction.h"
#import "UAActionRunner.h"
#import "UAActionRegistrar.h"

@interface UAActionRunnerTest : XCTestCase

@end

@implementation UAActionRunnerTest


NSString *actionName = @"ActionName";
NSString *anotherActionName = @"AnotherActionName";

- (void)tearDown {
    // Clear possible actions that were registered in the tests
    [[UAActionRegistrar shared] registerAction:nil name:actionName];
    [[UAActionRegistrar shared] registerAction:nil name:anotherActionName];

    [super tearDown];
}

/**
 * Test running an action
 */
- (void)testRunAction {
    __block BOOL didCompletionHandlerRun = NO;

    UAActionArguments *arguments = [UAActionArguments argumentsWithValue:@"value" withSituation:UASituationForegroundPush];
    UAActionResult *result = [UAActionResult none];

    UAAction *action = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
        XCTAssertEqualObjects(args, arguments, @"Runner should pass the supplied arguments to the action");
        completionHandler(result);
    }];

    [UAActionRunner runAction:action withArguments:arguments withCompletionHandler:^(UAActionResult *finalResult) {
        didCompletionHandlerRun = YES;
        XCTAssertEqualObjects(result, finalResult, @"Runner completion handler did not receive the action's results");
    }];

    XCTAssertTrue(didCompletionHandlerRun, @"Runner completion handler did not run");
}

/**
 * Test running an action from a name
 */
- (void)testRunActionWithName {
    __block BOOL didCompletionHandlerRun = NO;
    __block BOOL didActionRun = NO;

    UAActionArguments *arguments = [UAActionArguments argumentsWithValue:@"value" withSituation:UASituationForegroundPush];

    UAAction *action = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
        didActionRun = YES;
        XCTAssertEqualObjects(args, arguments, @"Runner should pass the supplied arguments to the action");
        completionHandler([UAActionResult none]);
    }];

    [[UAActionRegistrar shared] registerAction:action name:actionName];

    [UAActionRunner runActionWithName:actionName withArguments:arguments withCompletionHandler:^(UAActionResult *finalResult) {
        didCompletionHandlerRun = YES;
        XCTAssertEqual(finalResult.fetchResult, UAActionFetchResultNoData, @"Action that did not run should return a UAActionFetchResultNoData fetch result");
    }];

    XCTAssertTrue(didCompletionHandlerRun, @"Runner completion handler did not run");
    XCTAssertTrue(didActionRun, @"Runner should run action if no predicate is defined");

    didActionRun = NO;
    didCompletionHandlerRun = NO;

    [UAActionRunner runActionWithName:@"nopenopenopenopenope"
                        withArguments:nil
                withCompletionHandler:^(UAActionResult *result){
                    XCTAssertNotNil(result.error, @"a bad action name should result in an error");
                    XCTAssertNil(result.value, @"a bad action name should result in a nil value");
                    didCompletionHandlerRun = YES;
    }];

    XCTAssertTrue(didCompletionHandlerRun, @"completion handler should have run");

    didCompletionHandlerRun = NO;

    //re-register the action with a predicate guaranteed to fail
    [[UAActionRegistrar shared] registerAction:action name:actionName predicate:^(UAActionArguments *args){
        return NO;
    }];

    [UAActionRunner runActionWithName:actionName withArguments:arguments withCompletionHandler:^(UAActionResult *finalResult) {
        didCompletionHandlerRun = YES;
    }];

    XCTAssertTrue(didCompletionHandlerRun, @"completion handler should have run");
    XCTAssertFalse(didActionRun, @"action should not have run");
}

/**
 * Test running an action from a name with a predicate that returns NO
 */
- (void)testRunActionWithNameNoPredicate {
    __block BOOL didCompletionHandlerRun = NO;

    UAActionArguments *arguments = [UAActionArguments argumentsWithValue:@"value" withSituation:UASituationForegroundPush];

    UAAction *action = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
        XCTFail(@"Action should not run if the predicate returns NO");
        completionHandler([UAActionResult none]);
    }];

    [[UAActionRegistrar shared] registerAction:action name:actionName predicate:^BOOL(UAActionArguments *args) {
        XCTAssertEqualObjects(args, arguments, @"Runner should pass the supplied arguments to the action");
        return NO;
    }];

    [UAActionRunner runActionWithName:actionName withArguments:arguments withCompletionHandler:^(UAActionResult *finalResult) {
        didCompletionHandlerRun = YES;
        XCTAssertNil(finalResult.value, @"Action that did not run should return a nil value result");
        XCTAssertEqual(finalResult.fetchResult, UAActionFetchResultNoData, @"Action that did not run should return a UAActionFetchResultNoData fetch result");

    }];

    XCTAssertTrue(didCompletionHandlerRun, @"Runner completion handler did not run");
}

/**
 * Test running an action from a name with a predicate that returns YES
 */
- (void)testRunActionWithNameYESPredicate {
    __block BOOL didCompletionHandlerRun = NO;
    __block BOOL didActionRun = NO;

    UAActionArguments *arguments = [UAActionArguments argumentsWithValue:@"value" withSituation:UASituationForegroundPush];

    UAAction *action = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
        didActionRun = YES;
        XCTAssertEqualObjects(args, arguments, @"Runner should pass the supplied arguments to the action");
        completionHandler([UAActionResult none]);
    }];

    [[UAActionRegistrar shared] registerAction:action name:actionName predicate:^BOOL(UAActionArguments *args) {
        XCTAssertEqualObjects(args, arguments, @"Runner should pass the supplied arguments to the action");
        return YES;
    }];

    [UAActionRunner runActionWithName:actionName withArguments:arguments withCompletionHandler:^(UAActionResult *finalResult) {
        didCompletionHandlerRun = YES;
        XCTAssertEqual(finalResult.fetchResult, UAActionFetchResultNoData, @"Action that did not run should return a UAActionFetchResultNoData fetch result");
    }];

    XCTAssertTrue(didCompletionHandlerRun, @"Runner completion handler did not run");
    XCTAssertTrue(didActionRun, @"Runner should run action if predicate returns YES");
}

/**
 * Test trying to run an action from a name that is not registered
 */
- (void)testRunActionWithNameNotRegistered {
    __block BOOL didCompletionHandlerRun = NO;

    UAActionArguments *arguments = [UAActionArguments argumentsWithValue:@"value" withSituation:UASituationForegroundPush];

    [UAActionRunner runActionWithName:@"SomeUnregisteredActionName" withArguments:arguments withCompletionHandler:^(UAActionResult *finalResult) {
        didCompletionHandlerRun = YES;
        XCTAssertNil(finalResult.value, @"Action that did not run should return a nil value result");
        XCTAssertEqual(finalResult.fetchResult, UAActionFetchResultNoData, @"Action that did not run should return a UAActionFetchResultNoData fetch result");

    }];

    XCTAssertTrue(didCompletionHandlerRun, @"Runner completion handler did not run");
}

/**
 * Test running an empty dictionary of actions
 */
- (void)testRunActionsEmptyDictionary {
    __block BOOL didCompletionHandlerRun = NO;

    [UAActionRunner runActions:[NSDictionary dictionary] withCompletionHandler:^(UAActionResult *finalResult) {
        didCompletionHandlerRun = YES;

        // Should return an aggregate action result
        XCTAssertTrue([finalResult isKindOfClass:[UAAggregateActionResult class]], @"Running actions should return a UAAggregateActionResult");

        NSDictionary *resultDictionary = (NSDictionary  *)finalResult.value;


        XCTAssertEqual((NSUInteger) 0, resultDictionary.count, @"Should have an empty dictionary");
        XCTAssertEqual(finalResult.fetchResult, UAActionFetchResultNoData, @"Action that did not run should return a UAActionFetchResultNoData fetch result");
    }];

    XCTAssertTrue(didCompletionHandlerRun, @"Runner completion handler did not run");
}

/**
 * Test running a set of actions from a dictionary
 */
- (void)testRunActions {
    __block BOOL didCompletionHandlerRun = NO;
    __block int actionRunCount = 0;

    UAActionArguments *arguments = [UAActionArguments argumentsWithValue:@"value" withSituation:UASituationForegroundPush];

    UAAction *action = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
        actionRunCount++;
        XCTAssertEqualObjects(args, arguments, @"Runner should pass the supplied arguments to the action");
        completionHandler([UAActionResult none]);
    }];

    [[UAActionRegistrar shared] registerAction:action name:actionName predicate:^BOOL(UAActionArguments *args) {
        XCTAssertEqualObjects(args, arguments, @"Runner should pass the supplied arguments to the action");
        return YES;
    }];

    // Register another action
    [[UAActionRegistrar shared] registerAction:action name:anotherActionName predicate:^BOOL(UAActionArguments *args) {
        XCTAssertEqualObjects(args, arguments, @"Runner should pass the supplied arguments to the action");
        return YES;
    }];

    NSDictionary *actionsToRun = @{actionName : arguments, anotherActionName: arguments};
    [UAActionRunner runActions:actionsToRun withCompletionHandler:^(UAActionResult *finalResult) {
        didCompletionHandlerRun = YES;

        // Should return an aggregate action result
        XCTAssertTrue([finalResult isKindOfClass:[UAAggregateActionResult class]], @"Running actions should return a UAAggregateActionResult");

        NSDictionary *resultDictionary = (NSDictionary  *)finalResult.value;

        XCTAssertEqual((NSUInteger) 2, resultDictionary.count, @"Action should have 2 results");
    }];

    XCTAssertTrue(didCompletionHandlerRun, @"Runner completion handler did not run");
    XCTAssertEqual(2, actionRunCount, @"Both actions should of ran");
}

@end
