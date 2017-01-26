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
#import "UAAction.h"
#import "UAActionRunner+Internal.h"
#import "UAActionRegistry.h"
#import <OCMock/OCMock.h>
#import "UAirship.h"

@interface UAActionRunnerTest : XCTestCase
@property (nonatomic, strong) UAActionRegistry *registry;
@property (nonatomic, strong) id mockAirship;
@end

@implementation UAActionRunnerTest

NSString *actionName = @"ActionName";
NSString *anotherActionName = @"AnotherActionName";

- (void)setUp {
    [super setUp];
    self.registry = [UAActionRegistry defaultRegistry];


    // Mock Airship
    self.mockAirship = [OCMockObject niceMockForClass:[UAirship class]];
    [[[self.mockAirship stub] andReturn:self.mockAirship] shared];
    [[[self.mockAirship stub] andReturn:self.registry] actionRegistry];
}

- (void)tearDown {
    [self.mockAirship stopMocking];

    [super tearDown];
}

/**
 * Test running an action from a name
 */
- (void)testRunActionWithName {
    __block BOOL didCompletionHandlerRun = NO;
    __block BOOL didActionRun = NO;

    UAAction *action = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
        didActionRun = YES;
        XCTAssertEqualObjects(@"value", args.value, @"Runner should pass the supplied value to the action");
        XCTAssertEqual(UASituationForegroundPush, args.situation, @"Runner should pass the situation to the action");

        NSDictionary  *expectedMetadata = @{ @"meta key": @"meta value", UAActionMetadataRegisteredName: actionName };
        XCTAssertEqualObjects(expectedMetadata, args.metadata, @"Runner should pass the action name in the metadata");

        completionHandler([UAActionResult emptyResult]);
    }];

    [self.registry registerAction:action name:actionName];

    [UAActionRunner runActionWithName:actionName
                                value:@"value"
                            situation:UASituationForegroundPush
                             metadata:@{@"meta key": @"meta value"}
                    completionHandler:^(UAActionResult *finalResult) {
                        didCompletionHandlerRun = YES;
                        XCTAssertEqual(finalResult.fetchResult, UAActionFetchResultNoData, @"Action should return a UAActionFetchResultNoData fetch result");
                        XCTAssertEqual(finalResult.status, UAActionStatusCompleted, @"Action should of ran and returned UAActionStatusCompleted status");
    }];

    XCTAssertTrue(didCompletionHandlerRun, @"Runner completion handler did not run");
    XCTAssertTrue(didActionRun, @"Runner should run action if no predicate is defined");

    didActionRun = NO;
    didCompletionHandlerRun = NO;


    [UAActionRunner runActionWithName:@"nopenopenopenopenope"
                                value:@"value"
                            situation:UASituationForegroundPush
                             metadata:nil
                    completionHandler:^(UAActionResult *result) {
                        XCTAssertEqual(result.status, UAActionStatusActionNotFound, "action should not be found");
                        XCTAssertNil(result.value, @"a bad action name should result in a nil value");
                        didCompletionHandlerRun = YES;
                    }];

    XCTAssertTrue(didCompletionHandlerRun, @"completion handler should have run");

    didCompletionHandlerRun = NO;

    //re-register the action with a predicate guaranteed to fail
    [self.registry registerAction:action name:actionName predicate:^(UAActionArguments *args) {
        return NO;
    }];


    [UAActionRunner runActionWithName:actionName
                                value:@"value"
                            situation:UASituationForegroundPush
                             metadata:nil
                    completionHandler:^(UAActionResult *finalResult) {
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

    UAAction *action = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
        XCTFail(@"Action should not run if the predicate returns NO");
        completionHandler([UAActionResult emptyResult]);
    }];

    [self.registry registerAction:action name:actionName predicate:^BOOL(UAActionArguments *args) {
        XCTAssertEqualObjects(@"value", args.value, @"Runner should pass the supplied value to the action");
        XCTAssertEqual(UASituationForegroundPush, args.situation, @"Runner should pass the situation to the action");

        NSDictionary  *expectedMetadata = @{ UAActionMetadataRegisteredName: actionName };
        XCTAssertEqualObjects(expectedMetadata, args.metadata, @"Runner should pass the action name in the metadata");
        return NO;
    }];


    [UAActionRunner runActionWithName:actionName
                                value:@"value"
                            situation:UASituationForegroundPush
                             metadata:nil
                    completionHandler:^(UAActionResult *finalResult) {
                        didCompletionHandlerRun = YES;
                        XCTAssertNil(finalResult.value, @"Action that did not run should return a nil value result");
                        XCTAssertEqual(finalResult.fetchResult, UAActionFetchResultNoData, @"Action that did not run should return a UAActionFetchResultNoData fetch result");
                        XCTAssertEqual(finalResult.status, UAActionStatusArgumentsRejected, @"Rejected arguments should return UAActionStatusArgumentsRejected status");
                    }];


    XCTAssertTrue(didCompletionHandlerRun, @"Runner completion handler did not run");
}

/**
 * Test running an action from a name with a predicate that returns YES
 */
- (void)testRunActionWithNameYESPredicate {
    __block BOOL didCompletionHandlerRun = NO;
    __block BOOL didActionRun = NO;

    UAAction *action = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
        didActionRun = YES;
        XCTAssertEqualObjects(@"value", args.value, @"Runner should pass the supplied value to the action");
        XCTAssertEqual(UASituationForegroundPush, args.situation, @"Runner should pass the situation to the action");

        NSDictionary  *expectedMetadata = @{ UAActionMetadataRegisteredName: actionName };
        XCTAssertEqualObjects(expectedMetadata, args.metadata, @"Runner should pass the action name in the metadata");

        completionHandler([UAActionResult emptyResult]);
    }];

    [self.registry registerAction:action name:actionName predicate:^BOOL(UAActionArguments *args) {
        XCTAssertEqualObjects(@"value", args.value, @"Runner should pass the supplied value to the action");
        XCTAssertEqual(UASituationForegroundPush, args.situation, @"Runner should pass the situation to the action");

        NSDictionary  *expectedMetadata = @{ UAActionMetadataRegisteredName: actionName };
        XCTAssertEqualObjects(expectedMetadata, args.metadata, @"Runner should pass the action name in the metadata");

        return YES;
    }];

    [UAActionRunner runActionWithName:actionName
                                value:@"value"
                            situation:UASituationForegroundPush
                             metadata:nil
                    completionHandler:^(UAActionResult *finalResult) {
                        didCompletionHandlerRun = YES;
                        XCTAssertNil(finalResult.value, @"Action that did not run should return a nil value result");
                        XCTAssertEqual(finalResult.fetchResult, UAActionFetchResultNoData, @"Action that did not run should return a UAActionFetchResultNoData fetch result");
                        XCTAssertEqual(finalResult.status, UAActionStatusCompleted, @"Action should of ran and returned UAActionStatusCompleted status");
                    }];

    XCTAssertTrue(didCompletionHandlerRun, @"Runner completion handler did not run");
    XCTAssertTrue(didActionRun, @"Runner should run action if predicate returns YES");
}

/**
 * Test trying to run an action from a name that is not registered
 */
- (void)testRunActionWithNameNotRegistered {
    __block BOOL didCompletionHandlerRun = NO;


    [UAActionRunner runActionWithName:@"SomeUnregisteredActionName"
                                value:@"value"
                            situation:UASituationWebViewInvocation
                             metadata:nil
                    completionHandler:^(UAActionResult *finalResult) {
                        didCompletionHandlerRun = YES;
                        XCTAssertNil(finalResult.value, @"Action that did not run should return a nil value result");
                        XCTAssertEqual(finalResult.fetchResult, UAActionFetchResultNoData, @"Action that did not run should return a UAActionFetchResultNoData fetch result");
                        XCTAssertEqual(finalResult.status, UAActionStatusActionNotFound, @"Not found action should return UAActionStatusActionNotFound status");
                    }];

    XCTAssertTrue(didCompletionHandlerRun, @"Runner completion handler did not run");
}



/**
 * Test running an empty dictionary of actions
 */
- (void)testRunActionsEmptyDictionary {
    __block BOOL didCompletionHandlerRun = NO;


    [UAActionRunner runActionsWithActionValues:[NSDictionary dictionary]
                                     situation:UASituationWebViewInvocation
                                      metadata:nil
                             completionHandler:^(UAActionResult *finalResult) {
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
 * Test running an action
 */
- (void)testRunAction {
    __block BOOL didCompletionHandlerRun = NO;
    
    UAActionResult *result = [UAActionResult emptyResult];
    
    UAAction *action = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
        XCTAssertEqualObjects(@"value", args.value, @"Runner should pass the supplied value to the action");
        XCTAssertEqual(UASituationLaunchedFromPush, args.situation, @"Runner should pass the situation to the action");
        XCTAssertNil(args.metadata, @"Runner should pass the action name in the metadata");
        completionHandler(result);
    }];


    [UAActionRunner runAction:action value:@"value" situation:UASituationLaunchedFromPush metadata:nil completionHandler:^(UAActionResult *finalResult) {
        didCompletionHandlerRun = YES;
        XCTAssertEqualObjects(result, finalResult, @"Runner completion handler did not receive the action's results");
    }];
    
    XCTAssertTrue(didCompletionHandlerRun, @"Runner completion handler did not run");
}

/**
 * Test running a set of actions from a dictionary
 */
- (void)testRunActionPayload {
    __block BOOL didCompletionHandlerRun = NO;
    __block int actionRunCount = 0;


    UAAction *action = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
        actionRunCount++;

        XCTAssertEqualObjects(@"value", args.value, @"Runner should pass the supplied value to the action");
        XCTAssertEqual(UASituationManualInvocation, args.situation, @"Runner should pass the situation to the action");

        NSDictionary  *expectedMetadata = @{ @"meta key": @"meta value", UAActionMetadataRegisteredName: actionName };
        XCTAssertEqualObjects(expectedMetadata, args.metadata, @"Runner should pass the action name in the metadata");

        completionHandler([UAActionResult emptyResult]);
    }];

    // Verify the predicate is called
    [self.registry registerAction:action name:actionName predicate:^BOOL(UAActionArguments *args) {
        XCTAssertEqualObjects(@"value", args.value, @"Runner should pass the supplied value to the action");
        XCTAssertEqual(UASituationManualInvocation, args.situation, @"Runner should pass the situation to the action");

        NSDictionary  *expectedMetadata = @{ @"meta key": @"meta value", UAActionMetadataRegisteredName: actionName };
        XCTAssertEqualObjects(expectedMetadata, args.metadata, @"Runner should pass the action name in the metadata");

        return YES;
    }];

    UAAction *anotherAction = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
        actionRunCount++;

        XCTAssertEqualObjects(@"another value", args.value, @"Runner should pass the supplied value to the action");
        XCTAssertEqual(UASituationManualInvocation, args.situation, @"Runner should pass the situation to the action");

        NSDictionary  *expectedMetadata = @{ @"meta key": @"meta value", UAActionMetadataRegisteredName: anotherActionName };
        XCTAssertEqualObjects(expectedMetadata, args.metadata, @"Runner should pass the action name in the metadata");

        completionHandler([UAActionResult emptyResult]);
    }];


    // Register another action
    [self.registry registerAction:anotherAction name:anotherActionName predicate:^BOOL(UAActionArguments *args) {
        XCTAssertEqualObjects(@"another value", args.value, @"Runner should pass the supplied value to the action");
        XCTAssertEqual(UASituationManualInvocation, args.situation, @"Runner should pass the situation to the action");

        NSDictionary  *expectedMetadata = @{ @"meta key": @"meta value", UAActionMetadataRegisteredName: anotherActionName };
        XCTAssertEqualObjects(expectedMetadata, args.metadata, @"Runner should pass the action name in the metadata");

        return YES;
    }];

    NSDictionary *actionPayload = @{actionName : @"value", anotherActionName: @"another value"};
    [UAActionRunner runActionsWithActionValues:actionPayload situation:UASituationManualInvocation metadata:@{@"meta key": @"meta value"}
                             completionHandler:^(UAActionResult *finalResult) {
                                 didCompletionHandlerRun = YES;

                                 // Should return an aggregate action result
                                 XCTAssertTrue([finalResult isKindOfClass:[UAAggregateActionResult class]], @"Running actions should return a UAAggregateActionResult");

                                 NSDictionary *resultDictionary = (NSDictionary  *)finalResult.value;

                                 XCTAssertEqual((NSUInteger) 2, resultDictionary.count, @"Action should have 2 results");
                             }];

    XCTAssertTrue(didCompletionHandlerRun, @"Runner completion handler did not run");
    XCTAssertEqual(2, actionRunCount, @"Both actions should of ran");
}



/**
 * Test running an action with a null completion handler
 */
- (void)testRunActionNullCompletionHandler {
    UAActionResult *result = [UAActionResult emptyResult];
    
    UAAction *action = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
        completionHandler(result);
    }];
    
    XCTAssertNoThrow([UAActionRunner runAction:action value:@"value" situation:UASituationForegroundPush], "Null completion handler should not throw an exception");
}




@end
