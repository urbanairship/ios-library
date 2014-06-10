
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "UAActionRegistry.h"
#import "UAActionJSDelegate.h"
#import "NSJSONSerialization+UAAdditions.h"
#import "UAWebViewCallData.h"

@interface UAActionJSDelegateTest : XCTestCase
@property(nonatomic, strong) UAActionJSDelegate *jsDelegate;
@end

@implementation UAActionJSDelegateTest

- (void)setUp {
    [super setUp];
    self.jsDelegate = [[UAActionJSDelegate alloc] init];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testRunActionCB {

    __block BOOL ran = NO;
    __block NSString *result;

    UAAction *test = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler handler){
        ran = YES;
        handler([UAActionResult resultWithValue:@"howdy"]);
    }];

    [[UAActionRegistry shared] registerAction:test name:@"test_action"];

    UAAction *unserializable = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler handler){
        ran = YES;
        handler([UAActionResult resultWithValue:self]);
    }];

    [[UAActionRegistry shared] registerAction:unserializable name:@"unserializable"];


    NSURL *url = [NSURL URLWithString:@"uairship://run-action-cb/some-callback-ID?test_action=%22hi%22"];
    UAWebViewCallData *data = [UAWebViewCallData callDataForURL:url
                                                        webView:nil];


    [self.jsDelegate callWithData:data withCompletionHandler:^(NSString *script){
        result = script;
    }];

    XCTAssertEqualObjects(result, @"UAirship.finishAction(null, '\"howdy\"', 'some-callback-ID');", @"resulting script should pass a null error, the result value 'howdy', and the provided callback ID");
    XCTAssertTrue(ran, @"the action should have been run");

    //this produces an unserializable result, which should be converted into a string description
    url = [NSURL URLWithString:@"uairship://run-action-cb/some-callback-ID?unserializable=%22hi%22"];
    data = [UAWebViewCallData callDataForURL:url
                                     webView:nil];

    [self.jsDelegate callWithData:data withCompletionHandler:^(NSString *script){
        result = script;
    }];

    NSString *expectedResult = [NSString stringWithFormat:@"UAirship.finishAction(null, '\"%@\"', 'some-callback-ID');", self.description];
    XCTAssertEqualObjects(result, expectedResult, @"resulting script should pass a null error, the description of the result, and the provided callback ID");

    [[UAActionRegistry shared] removeEntryWithName:@"test_action"];
    [[UAActionRegistry shared] removeEntryWithName:@"unserializable"];
}

- (void)testRunActionCBInvalidArgs {
    __block BOOL ran = NO;
    __block NSString *result;

    // Invalid action argument value because it is not properly JSON encoded
    NSURL *url = [NSURL URLWithString:@"uairship://run-action-cb/some-callback-ID?test_action=blah"];
    UAWebViewCallData *data = [UAWebViewCallData callDataForURL:url
                                                        webView:nil];

    UAAction *test = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler handler){
        ran = YES;
        handler([UAActionResult resultWithValue:@"howdy"]);
    }];

    [[UAActionRegistry shared] registerAction:test name:@"test_action"];

    [self.jsDelegate callWithData:data withCompletionHandler:^(NSString *script){
        result = script;
    }];

    XCTAssertEqualObjects(result, @"UAirship.finishAction(new Error('Error decoding arguments: blah'), null, 'some-callback-ID');", @"resulting script should pass an arguments encoding error, a null result value, and the provided callback ID");
    [[UAActionRegistry shared] removeEntryWithName:@"test_action"];
}

- (void)testRunActionCBInvalidAction {
    __block NSString *result;

    NSURL *url = [NSURL URLWithString:@"uairship://run-action-cb/some-callback-ID?bogus_action=%22hi%22"];
    UAWebViewCallData *data = [UAWebViewCallData callDataForURL:url
                                                        webView:nil];

    [self.jsDelegate callWithData:data withCompletionHandler:^(NSString *script){
        result = script;
    }];

    XCTAssertEqualObjects(result, @"UAirship.finishAction(new Error('No action found with name bogus_action, skipping action.'), null, 'some-callback-ID');",@"resulting script should pass an action retrieval error, a null result value, and the provided callback ID");
}

- (void)testRunActionCBEmptyArgs {
    __block NSString *result;
    __block BOOL ran = NO;

    UAAction *test = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler handler){
        ran = YES;
        handler([UAActionResult resultWithValue:@"howdy"]);
    }];

    [[UAActionRegistry shared] registerAction:test name:@"test_action"];

    NSURL *url = [NSURL URLWithString:@"uairship://run-action-cb/some-callback-ID?test_action"];
    UAWebViewCallData *data = [UAWebViewCallData callDataForURL:url
                                                        webView:nil];

    [self.jsDelegate callWithData:data withCompletionHandler:^(NSString *script){
        result = script;
    }];

    XCTAssertTrue(ran, @"the action should have been run");
    XCTAssertEqualObjects(result, @"UAirship.finishAction(null, '\"howdy\"', 'some-callback-ID');", @"resulting script should pass a null error, the result value 'howdy', and the provided callback ID");
    [[UAActionRegistry shared] removeEntryWithName:@"test_action"];
}

- (void)testRunActionCBNoCallback {
    __block NSString *result;
    __block BOOL ran = NO;

    UAAction *test = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler handler){
        ran = YES;
        handler([UAActionResult resultWithValue:@"howdy"]);
    }];

    [[UAActionRegistry shared] registerAction:test name:@"test_action"];

    NSURL *url = [NSURL URLWithString:@"uairship://run-action-cb?test_action"];
    UAWebViewCallData *data = [UAWebViewCallData callDataForURL:url
                                                        webView:nil];

    [self.jsDelegate callWithData:data withCompletionHandler:^(NSString *script){
        result = script;
    }];

    XCTAssertTrue(ran, @"the action should have been run");
    XCTAssertNil(result, @"resulting script value should be nil if there is not callback ID");
    [[UAActionRegistry shared] removeEntryWithName:@"test_action"];
}


- (void)testRunAction {
    __block BOOL ran = NO;
    __block BOOL alsoRan = NO;
    __block NSString *result;

    UAAction *test = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler handler){
        ran = YES;
        handler([UAActionResult resultWithValue:@"howdy"]);
    }];

    UAAction *alsoTest = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler handler){
        alsoRan = YES;
        handler([UAActionResult resultWithValue:@"yeah!"]);
    }];

    [[UAActionRegistry shared] registerAction:test name:@"test_action"];
    [[UAActionRegistry shared] registerAction:alsoTest name:@"also_test_action"];


    NSURL *url = [NSURL URLWithString:@"uairship://run-actions?test_action=%22hi%22&also_test_action"];
    UAWebViewCallData *data = [UAWebViewCallData callDataForURL:url
                                                        webView:nil];

    [self.jsDelegate callWithData:data withCompletionHandler:^(NSString *script){
        result = script;
    }];

    XCTAssertNil(result, @"run-basic-actions should not produce a script result");
    XCTAssertTrue(ran, @"the action should have run");
    XCTAssertTrue(alsoRan, @"the other action should have run");

    [[UAActionRegistry shared] removeEntryWithName:@"test_action"];
    [[UAActionRegistry shared] removeEntryWithName:@"also_test_action"];
}

- (void)testRunActionInvalidAction {
    __block NSString *result;

    NSURL *url = [NSURL URLWithString:@"uairship://run-actions?bogus_action=%22hi$22"];
    UAWebViewCallData *data = [UAWebViewCallData callDataForURL:url
                                                        webView:nil];

    [self.jsDelegate callWithData:data withCompletionHandler:^(NSString *script){
        result = script;
    }];

    XCTAssertNil(result, @"run-basic-actions should not produce a script result");
}


- (void)testRunActionInvalidArgs {
    __block NSString *result;
    __block BOOL ran = NO;


    UAAction *test = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler handler){
        ran = YES;
        handler([UAActionResult resultWithValue:@"howdy"]);
    }];

    [[UAActionRegistry shared] registerAction:test name:@"test_action"];


    NSURL *url = [NSURL URLWithString:@"uairship://run-actions?test_action=blah"];
    UAWebViewCallData *data = [UAWebViewCallData callDataForURL:url
                                                        webView:nil];

    [self.jsDelegate callWithData:data withCompletionHandler:^(NSString *script){
        result = script;
    }];

    XCTAssertFalse(ran, @"no action should have run");
    XCTAssertNil(result, @"run-basic-actions should not produce a script result");

    [[UAActionRegistry shared] removeEntryWithName:@"test_action"];
}

- (void)testRunActionsMultipleArgs {
    __block int runCount = 0;
    __block NSString *result;

    UAAction *test = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler handler){
        runCount ++;
        handler([UAActionResult resultWithValue:@"howdy"]);
    }];

    [[UAActionRegistry shared] registerAction:test name:@"test_action"];


    NSURL *url = [NSURL URLWithString:@"uairship://run-actions?test_action&test_action"];
    UAWebViewCallData *data = [UAWebViewCallData callDataForURL:url
                                                        webView:nil];

    [self.jsDelegate callWithData:data withCompletionHandler:^(NSString *script){
        result = script;
    }];

    XCTAssertNil(result, @"run-actions should not produce a script result");
    XCTAssertEqual(runCount, 2, @"the action should have run 2 times");

    [[UAActionRegistry shared] removeEntryWithName:@"test_action"];
}


- (void)testRunBasicAction {
    __block BOOL ran = NO;
    __block BOOL alsoRan = NO;
    __block NSString *result;

    UAAction *test = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler handler){
        ran = YES;
        handler([UAActionResult resultWithValue:@"howdy"]);
    }];

    UAAction *alsoTest = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler handler){
        alsoRan = YES;
        handler([UAActionResult resultWithValue:@"yeah!"]);
    }];

    [[UAActionRegistry shared] registerAction:test name:@"test_action"];
    [[UAActionRegistry shared] registerAction:alsoTest name:@"also_test_action"];

    NSURL *url = [NSURL URLWithString:@"uairship://run-basic-actions?test_action=hi&also_test_action"];
    
    UAWebViewCallData *data = [UAWebViewCallData callDataForURL:url
                                                        webView:nil];

    [self.jsDelegate callWithData:data withCompletionHandler:^(NSString *script){
        result = script;
    }];

    XCTAssertNil(result, @"run-basic-actions should not produce a script result");
    XCTAssertTrue(ran, @"the action should have run");
    XCTAssertTrue(alsoRan, @"the other action should have run");

    [[UAActionRegistry shared] removeEntryWithName:@"test_action"];
    [[UAActionRegistry shared] removeEntryWithName:@"also_test_action"];
}

- (void)testRunBasicActionMultipleArgs {
     __block int runCount = 0;
    __block NSString *result;

    UAAction *test = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler handler){
        runCount ++;
        handler([UAActionResult resultWithValue:@"howdy"]);
    }];

    [[UAActionRegistry shared] registerAction:test name:@"test_action"];


    NSURL *url = [NSURL URLWithString:@"uairship://run-basic-actions?test_action&test_action"];
    UAWebViewCallData *data = [UAWebViewCallData callDataForURL:url
                                                        webView:nil];

    [self.jsDelegate callWithData:data withCompletionHandler:^(NSString *script){
        result = script;
    }];

    XCTAssertNil(result, @"run-basic-actions should not produce a script result");
    XCTAssertEqual(runCount, 2, @"the action should have run 2 times");

    [[UAActionRegistry shared] removeEntryWithName:@"test_action"];
}

- (void)testRunInvalidAction {
    __block NSString *result;

    NSURL *url = [NSURL URLWithString:@"uairship://run-basic-actions?bogus_action=hi"];
    UAWebViewCallData *data = [UAWebViewCallData callDataForURL:url
                                                        webView:nil];

    [self.jsDelegate callWithData:data withCompletionHandler:^(NSString *script){
        result = script;
    }];

    XCTAssertNil(result, @"run-basic-actions should not produce a script result");
}

@end
