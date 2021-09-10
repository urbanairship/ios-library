/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "AirshipTests-Swift.h"

@import AirshipCore;

@interface UANativeBridgeActionHandlerTest : UABaseTest
@property (nonatomic, strong) NativeBridgeActionHandler *actionHandler;
@property (nonatomic, strong) UAActionRegistry *registry;
@property(nonatomic, strong) UATestAirshipInstance *airship;
@property (nonatomic, copy) NSString *nativeBridge;
@end

@implementation UANativeBridgeActionHandlerTest

- (void)setUp {
    [super setUp];
    self.actionHandler = [[NativeBridgeActionHandler alloc] init];
    self.registry = [UAActionRegistry defaultRegistry];

    self.airship = [[UATestAirshipInstance alloc] init];
    self.airship.actionRegistry = self.registry;
    [self.airship makeShared];
}

/**
 * Test running actions with a callback.
 */
- (void)testRunActionCB {
    UABlockAction *test = [[UABlockAction alloc] initWithBlock:^(UAActionArguments *args, UAActionCompletionHandler handler) {
        handler([UAActionResult resultWithValue:args.value]);
    }];

    [self.registry registerAction:test name:@"test_action"];

    NSURL *URL = [NSURL URLWithString:@"uairship://run-action-cb/test_action/%22hi%22/callback-ID-1"];
    NSString *result = [self performWebViewCallWithURL:URL];

    NSString *expectedResult = [UANativeBridgeActionHandlerTest actionResult:@"hi" callbackID:@"callback-ID-1"];
    XCTAssertEqualObjects(expectedResult, result);
}

/**
 * Test action result returns the result's description if it's unable to be serialized.
 */
- (void)testRunActionCBUnserializableResult {
    UABlockAction *unserializable = [[UABlockAction alloc] initWithBlock:^(UAActionArguments *args, UAActionCompletionHandler handler) {
        handler([UAActionResult resultWithValue:self]);
    }];

    [self.registry registerAction:unserializable name:@"unserializable"];

    //this produces an unserializable result, which should be converted into a string description
    NSURL *URL = [NSURL URLWithString:@"uairship://run-action-cb/unserializable/%22hi%22/callback-ID-2"];
    NSString *result = [self performWebViewCallWithURL:URL];

    NSString *expectedResult = [UANativeBridgeActionHandlerTest actionResult:self.description callbackID:@"callback-ID-2"];
    XCTAssertEqualObjects(expectedResult, result);
}

/**
 * Test running an action with a callback with invalid number of arguments.
 */
- (void)testRunActionCBInvalidArgs {
    // Invalid action argument value because it is missing arguments
    NSURL *URL = [NSURL URLWithString:@"uairship://run-action-cb/junk"];
    NSString *result = [self performWebViewCallWithURL:URL];
    XCTAssertNil(result);
}

/**
 * Test running an action with a callback, when specifying a non-existent action
 */
- (void)testRunActionCBInvalidAction {
    // This action doesn't exist, so should result in an error
    NSURL *URL = [NSURL URLWithString:@"uairship://run-action-cb/bogus_action/%22hi%22/callback-ID-1"];
    NSString *result = [self performWebViewCallWithURL:URL];

    NSString *expectedResult = [UANativeBridgeActionHandlerTest errorCallbackResult:@"No action found with name bogus_action, skipping action."
                                                                         callbackID:@"callback-ID-1"];
    XCTAssertEqualObjects(expectedResult, result);
}

/**
 * Test running an action with a callback and no arguments
 */
- (void)testRunActionCBEmptyArgs {
    UABlockAction *test = [[UABlockAction alloc] initWithBlock:^(UAActionArguments *args, UAActionCompletionHandler handler) {
        XCTAssertEqual(args.value, [NSNull null]);
        handler([UAActionResult resultWithValue:@"howdy"]);
    }];

    [self.registry registerAction:test name:@"test_action"];

    NSURL *URL = [NSURL URLWithString:@"uairship://run-action-cb/test_action/null/callback-ID-1"];
    NSString *result = [self performWebViewCallWithURL:URL];

    NSString *expectedResult = [UANativeBridgeActionHandlerTest actionResult:@"howdy" callbackID:@"callback-ID-1"];
    XCTAssertEqualObjects(expectedResult, result);
}


/**
 * Test the run-actions variant
 */
- (void)testRunActions {
    __block BOOL ran = NO;
    __block BOOL alsoRan = NO;

    UABlockAction *test = [[UABlockAction alloc] initWithBlock:^(UAActionArguments *args, UAActionCompletionHandler handler) {
        ran = YES;
        handler([UAActionResult resultWithValue:@"howdy"]);
    }];

    UABlockAction *alsoTest = [[UABlockAction alloc] initWithBlock:^(UAActionArguments *args, UAActionCompletionHandler handler) {
        alsoRan = YES;
        handler([UAActionResult resultWithValue:@"yeah!"]);
    }];

    [self.registry registerAction:test name:@"test%20action"];
    [self.registry registerAction:alsoTest name:@"also_test_action"];

    NSURL *url = [NSURL URLWithString:@"uairship://run-actions?test%2520action=%22hi%22&also_test_action"];

    NSString *result = [self performWebViewCallWithURL:url];
    XCTAssertTrue(ran, @"the action should have run");
    XCTAssertTrue(alsoRan, @"the other action should have run");
    XCTAssertNil(result);
}

/**
 * Test encoding a non-existent action name in the run-actions variant
 */
- (void)testRunActionsInvalidAction {
    NSURL *url = [NSURL URLWithString:@"uairship://run-actions?bogus_action=%22hi$22"];
    NSString *result = [self performWebViewCallWithURL:url];

    XCTAssertNil(result, @"run-actions should not produce a script result");
}

/**
 * Test encoding invalid arguments in the run-actions variant
 */
- (void)testRunActionsInvalidArgs {
    __block BOOL ran = NO;
    UABlockAction *test = [[UABlockAction alloc] initWithBlock:^(UAActionArguments *args, UAActionCompletionHandler handler) {
        ran = YES;
        handler([UAActionResult resultWithValue:@"howdy"]);
    }];

    [self.registry registerAction:test name:@"test_action"];

    NSURL *url = [NSURL URLWithString:@"uairship://run-actions?test_action=blah"];
    NSString *result = [self performWebViewCallWithURL:url];

    XCTAssertFalse(ran, @"no action should have run");
    XCTAssertNil(result, @"run-basic-actions should not produce a script result");
}

/**
 * Test encoding the same args multiple times in the run-actions variant
 */
- (void)testRunActionsMultipleArgs {
    __block int runCount = 0;
    UABlockAction *test = [[UABlockAction alloc] initWithBlock:^(UAActionArguments *args, UAActionCompletionHandler handler) {
        runCount ++;
        handler([UAActionResult resultWithValue:@"howdy"]);
    }];

    [self.registry registerAction:test name:@"test_action"];

    NSURL *url = [NSURL URLWithString:@"uairship://run-actions?test_action&test_action"];
    NSString *result = [self performWebViewCallWithURL:url];

    XCTAssertNil(result, @"run-actions should not produce a script result");
    XCTAssertEqual(runCount, 2, @"the action should have run 2 times");
}

/**
 * Test the run-basic-actions variant
 */
- (void)testRunBasicActions {
    __block BOOL ran = NO;
    __block BOOL alsoRan = NO;

    UABlockAction *test = [[UABlockAction alloc] initWithBlock:^(UAActionArguments *args, UAActionCompletionHandler handler) {
        ran = YES;
        handler([UAActionResult resultWithValue:@"howdy"]);
    }];

    UABlockAction *alsoTest = [[UABlockAction alloc] initWithBlock:^(UAActionArguments *args, UAActionCompletionHandler handler) {
        alsoRan = YES;
        handler([UAActionResult resultWithValue:@"yeah!"]);
    }];

    [self.registry registerAction:test name:@"test_action"];
    [self.registry registerAction:alsoTest name:@"also_test_action"];

    NSURL *url = [NSURL URLWithString:@"uairship://run-basic-actions?test_action=hi&also_test_action"];
    NSString *result = [self performWebViewCallWithURL:url];

    XCTAssertNil(result, @"run-basic-actions should not produce a script result");
    XCTAssertTrue(ran, @"the action should have run");
    XCTAssertTrue(alsoRan, @"the other action should have run");
}

/**
 * Test encoding multiple instances of the same argument in the run-basic-actions variant
 */
- (void)testRunBasicActionsMultipleArgs {
     __block int runCount = 0;
    UABlockAction *test = [[UABlockAction alloc] initWithBlock:^(UAActionArguments *args, UAActionCompletionHandler handler) {
        runCount ++;
        handler([UAActionResult resultWithValue:@"howdy"]);
    }];

    [self.registry registerAction:test name:@"test_action"];

    NSURL *url = [NSURL URLWithString:@"uairship://run-basic-actions?test_action&test_action"];
    NSString *result = [self performWebViewCallWithURL:url];

    XCTAssertNil(result, @"run-basic-actions should not produce a script result");
    XCTAssertEqual(runCount, 2, @"the action should have run 2 times");
}

/**
 * Test encoding a non-existent action in the run-basic-actions variant
 */
- (void)testRunInvalidAction {
    NSURL *url = [NSURL URLWithString:@"uairship://run-basic-actions?bogus_action=hi"];
    NSString *result = [self performWebViewCallWithURL:url];

    XCTAssertNil(result, @"run-basic-actions should not produce a script result");
}

- (NSString *)performWebViewCallWithURL:(NSURL *)URL {
    id ran = [self expectationWithDescription:@"Performing command"];

    __block NSString *result;
    UAJavaScriptCommand *command = [UAJavaScriptCommand commandForURL:URL];
    [self.actionHandler runActionsForCommand:command metadata:@{} completionHandler:^(NSString *script) {
        result = script;
        [ran fulfill];
    }];

    [self waitForTestExpectations];
    return result;
}

+ (NSString *)errorCallbackResult:(NSString *)error callbackID:(NSString *)callbackID {
    return [NSString stringWithFormat:@"var error = new Error(); error.message = \"%@\"; UAirship.finishAction(error, null, \"%@\");", error, callbackID];
}

+ (NSString *)actionResult:(NSString *)result callbackID:(NSString *)callbackID {
    return [NSString stringWithFormat:@"UAirship.finishAction(null, \"%@\", \"%@\");", result, callbackID];
}

@end
