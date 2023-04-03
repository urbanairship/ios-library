/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UAAction.h"
#import "AirshipTests-Swift.h"

@import AirshipCore;

@interface UAActionRunnerTest : UABaseTest
@property (nonatomic, strong) UAActionRegistry *registry;
@property (nonatomic, strong) UATestAirshipInstance *airship;
@end

@implementation UAActionRunnerTest

NSString *actionName = @"ActionName";
NSString *anotherActionName = @"AnotherActionName";

- (void)setUp {
    [super setUp];
    
    self.registry = [UAActionRegistry defaultRegistry];

    self.airship = [[UATestAirshipInstance alloc] init];
    self.airship.actionRegistry = self.registry;
    [self.airship makeShared];
}

/**
 * Test running an action from a name
 */
- (void)testRunActionWithName {
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Completion handler ran"];
    __block BOOL didActionRun = NO;

    UABlockAction *action = [[UABlockAction alloc] initWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
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
                        [expectation fulfill];
                        XCTAssertEqual(finalResult.fetchResult, UAActionFetchResultNoData, @"Action should return a UAActionFetchResultNoData fetch result");
                        XCTAssertEqual(finalResult.status, UAActionStatusCompleted, @"Action should of ran and returned UAActionStatusCompleted status");
    }];

    [self waitForTestExpectations];
    XCTAssertTrue(didActionRun, @"Runner should run action if no predicate is defined");

    didActionRun = NO;
    expectation = [self expectationWithDescription:@"Completion handler ran"];

    [UAActionRunner runActionWithName:@"nopenopenopenopenope"
                                value:@"value"
                            situation:UASituationForegroundPush
                             metadata:nil
                    completionHandler:^(UAActionResult *result) {
                        XCTAssertEqual(result.status, UAActionStatusActionNotFound, "action should not be found");
                        XCTAssertNil(result.value, @"a bad action name should result in a nil value");
                        [expectation fulfill];
                    }];

    [self waitForTestExpectations];
    expectation = [self expectationWithDescription:@"Completion handler ran"];

    //re-register the action with a predicate guaranteed to fail
    [self.registry registerAction:action name:actionName predicate:^(UAActionArguments *args) {
        return NO;
    }];


    [UAActionRunner runActionWithName:actionName
                                value:@"value"
                            situation:UASituationForegroundPush
                             metadata:nil
                    completionHandler:^(UAActionResult *finalResult) {
                        [expectation fulfill];
                    }];

    [self waitForTestExpectations];
    XCTAssertFalse(didActionRun, @"action should not have run");
}

/**
 * Test running action any given action name for an action with three action names registered
 */
- (void)testRunActionThreeActionNames {
    __block int actionRunCount = 0;
    NSString *thirdActionName = @"A Third Action Name";

    UABlockAction *action = [[UABlockAction alloc] initWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
        actionRunCount++;
        completionHandler([UAActionResult emptyResult]);
    }];

    void (^completionBlock)(UAActionResult *, XCTestExpectation *) = ^void(UAActionResult *finalResult, XCTestExpectation *expectation) {
        XCTAssertTrue([finalResult isKindOfClass:[UAAggregateActionResult class]], @"Running actions should return a UAAggregateActionResult");
                                NSDictionary *resultDictionary = (NSDictionary  *)finalResult.value;
                                XCTAssertEqual((NSUInteger) 1, resultDictionary.count, @"Action should have 1 result");
        [expectation fulfill];
    };

    // Register both action names
    [self.registry registerAction:action names:@[actionName, anotherActionName, thirdActionName]];

    __block XCTestExpectation *expectation = [self expectationWithDescription:@"Completion handler ran"];
    NSDictionary *actionNamePayload = @{actionName : @"firstvalue"};
    [UAActionRunner runActionsWithActionValues:actionNamePayload situation:UASituationManualInvocation metadata:@{@"meta key": @"meta value"}
                             completionHandler:^(UAActionResult *finalResult) {
                                completionBlock(finalResult, expectation);
                             }];

    [self waitForTestExpectations];
    XCTAssertEqual(1, actionRunCount);

    __block XCTestExpectation *anotherExpectation = [self expectationWithDescription:@"Completion handler ran"];
    NSDictionary *anotherActionNamePayload = @{anotherActionName : @"secondvalue"};
    [UAActionRunner runActionsWithActionValues:anotherActionNamePayload situation:UASituationManualInvocation metadata:@{@"meta key": @"meta value"}
                             completionHandler:^(UAActionResult *finalResult) {
                                 completionBlock(finalResult, anotherExpectation);
                             }];

    [self waitForTestExpectations];
    XCTAssertEqual(2, actionRunCount);

    __block XCTestExpectation *aThirdExpectation = [self expectationWithDescription:@"Completion handler ran"];
    NSDictionary *thirdActionNamePayload = @{thirdActionName : @"thirdvalue"};
    [UAActionRunner runActionsWithActionValues:thirdActionNamePayload situation:UASituationManualInvocation metadata:@{@"meta key": @"meta value"}
                             completionHandler:^(UAActionResult *finalResult) {
                                completionBlock(finalResult, aThirdExpectation);
                             }];

    [self waitForTestExpectations];
    XCTAssertEqual(3, actionRunCount);
}

/**
 * Test running an action from a name with a predicate that returns NO
 */
- (void)testRunActionWithNameNoPredicate {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Completion handler ran"];
   

    UABlockAction *action = [[UABlockAction alloc] initWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
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
                        [expectation fulfill];
                        XCTAssertNil(finalResult.value, @"Action that did not run should return a nil value result");
                        XCTAssertEqual(finalResult.fetchResult, UAActionFetchResultNoData, @"Action that did not run should return a UAActionFetchResultNoData fetch result");
                        XCTAssertEqual(finalResult.status, UAActionStatusArgumentsRejected, @"Rejected arguments should return UAActionStatusArgumentsRejected status");
                    }];


    [self waitForTestExpectations];
}

/**
 * Test running an action from a name with a predicate that returns YES
 */
- (void)testRunActionWithNameYESPredicate {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Completion handler ran"];
   
    __block BOOL didActionRun = NO;

    UABlockAction *action = [[UABlockAction alloc] initWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
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
                        [expectation fulfill];
                        XCTAssertNil(finalResult.value, @"Action that did not run should return a nil value result");
                        XCTAssertEqual(finalResult.fetchResult, UAActionFetchResultNoData, @"Action that did not run should return a UAActionFetchResultNoData fetch result");
                        XCTAssertEqual(finalResult.status, UAActionStatusCompleted, @"Action should of ran and returned UAActionStatusCompleted status");
                    }];

    [self waitForTestExpectations];
    XCTAssertTrue(didActionRun, @"Runner should run action if predicate returns YES");
}

/**
 * Test trying to run an action from a name that is not registered
 */
- (void)testRunActionWithNameNotRegistered {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Completion handler ran"];
   


    [UAActionRunner runActionWithName:@"SomeUnregisteredActionName"
                                value:@"value"
                            situation:UASituationWebViewInvocation
                             metadata:nil
                    completionHandler:^(UAActionResult *finalResult) {
                        [expectation fulfill];
                        XCTAssertNil(finalResult.value, @"Action that did not run should return a nil value result");
                        XCTAssertEqual(finalResult.fetchResult, UAActionFetchResultNoData, @"Action that did not run should return a UAActionFetchResultNoData fetch result");
                        XCTAssertEqual(finalResult.status, UAActionStatusActionNotFound, @"Not found action should return UAActionStatusActionNotFound status");
                    }];

    [self waitForTestExpectations];
}



/**
 * Test running an empty dictionary of actions
 */
- (void)testRunActionsEmptyDictionary {
    __block BOOL didCompletionHandlerRun = NO;

    XCTestExpectation *expectation = [self expectationWithDescription:@"Completion handler ran"];

    [UAActionRunner runActionsWithActionValues:[NSDictionary dictionary]
                                     situation:UASituationWebViewInvocation
                                      metadata:nil
                             completionHandler:^(UAActionResult *finalResult) {
                                 didCompletionHandlerRun = YES;

                                 // Should return an aggregate action result
                                 XCTAssertTrue([finalResult isKindOfClass:[UAAggregateActionResult class]], @"Running actions should return a UAAggregateActionResult");

                                 NSDictionary *resultDictionary = (NSDictionary  *)finalResult.value;
                                 [expectation fulfill];
                                 XCTAssertEqual((NSUInteger) 0, resultDictionary.count, @"Should have an empty dictionary");
                                 XCTAssertEqual(finalResult.fetchResult, UAActionFetchResultNoData, @"Action that did not run should return a UAActionFetchResultNoData fetch result");
                             }];

    [self waitForTestExpectations];
    XCTAssertTrue(didCompletionHandlerRun, @"Runner completion handler did not run");
}

/**
 * Test running an action
 */
- (void)testRunAction {
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Completion handler ran"];
    UAActionResult *result = [UAActionResult emptyResult];
    
    UABlockAction *action = [[UABlockAction alloc] initWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
        XCTAssertEqualObjects(@"value", args.value, @"Runner should pass the supplied value to the action");
        XCTAssertEqual(UASituationLaunchedFromPush, args.situation, @"Runner should pass the situation to the action");
        XCTAssertNil(args.metadata, @"Runner should pass the action name in the metadata");
        completionHandler(result);
    }];


    [UAActionRunner runAction:action value:@"value" situation:UASituationLaunchedFromPush metadata:nil completionHandler:^(UAActionResult *finalResult) {
        [expectation fulfill];
        XCTAssertEqualObjects(result, finalResult, @"Runner completion handler did not receive the action's results");
    }];
    
    [self waitForTestExpectations];
}

/**
 * Test running a set of actions from a dictionary
 */
- (void)testRunActionPayload {
    __block int actionRunCount = 0;

    UABlockAction *action = [[UABlockAction alloc] initWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
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

    UABlockAction *anotherAction = [[UABlockAction alloc] initWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
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

    XCTestExpectation *expectation = [self expectationWithDescription:@"Completion handler ran"];
    NSDictionary *actionPayload = @{actionName : @"value", anotherActionName: @"another value"};
    [UAActionRunner runActionsWithActionValues:actionPayload
                                     situation:UASituationManualInvocation metadata:@{@"meta key": @"meta value"}
                             completionHandler:^(UAActionResult *finalResult) {
                                 // Should return an aggregate action result
                                 XCTAssertTrue([finalResult isKindOfClass:[UAAggregateActionResult class]], @"Running actions should return a UAAggregateActionResult");

                                 NSDictionary *resultDictionary = (NSDictionary  *)finalResult.value;

                                 XCTAssertEqual((NSUInteger) 2, resultDictionary.count, @"Action should have 2 results");
 
                                 [expectation fulfill];
                             }];

    [self waitForTestExpectations];
    XCTAssertEqual(2, actionRunCount, @"Both actions should of ran");
}

/**
 * Test running a set of actions from a dictionary dedupes entries.
 */
- (void)testRunActionPayloadDedupes {
    __block int actionRunCount = 0;

    UABlockAction *action = [[UABlockAction alloc] initWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
        actionRunCount++;
        completionHandler([UAActionResult emptyResult]);
    }];

    // Verify the predicate is called
    [self.registry registerAction:action names:@[actionName, anotherActionName]];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Completion handler ran"];
    NSDictionary *actionPayload = @{actionName : @"value", anotherActionName: @"another value"};
    [UAActionRunner runActionsWithActionValues:actionPayload situation:UASituationManualInvocation metadata:@{@"meta key": @"meta value"}
                             completionHandler:^(UAActionResult *finalResult) {
                                 // Should return an aggregate action result
                                 XCTAssertTrue([finalResult isKindOfClass:[UAAggregateActionResult class]], @"Running actions should return a UAAggregateActionResult");
                                 NSDictionary *resultDictionary = (NSDictionary  *)finalResult.value;
                                 XCTAssertEqual((NSUInteger) 1, resultDictionary.count, @"Action should have 1 result");
                                 [expectation fulfill];
                             }];

    [self waitForTestExpectations];
    XCTAssertEqual(1, actionRunCount);
}

/**
 * Test running an action with a null completion handler
 */
- (void)testRunActionNullCompletionHandler {
    UAActionResult *result = [UAActionResult emptyResult];
    
    UABlockAction *action = [[UABlockAction alloc] initWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler) {
        completionHandler(result);
    }];
    
    XCTAssertNoThrow([UAActionRunner runAction:action value:@"value" situation:UASituationForegroundPush], "Null completion handler should not throw an exception");
}




@end
