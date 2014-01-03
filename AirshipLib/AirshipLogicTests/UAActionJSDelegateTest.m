
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "UAActionRegistrar.h"
#import "UAActionJSDelegate.h"
#import "NSJSONSerialization+UAAdditions.h"

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

- (void)testRunAction {

    __block BOOL ran = NO;
    __block NSString *result;

    UAAction *test = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler handler){
        ran = YES;
        handler([UAActionResult resultWithValue:@"howdy"]);
    }];

    [[UAActionRegistrar shared] registerAction:test name:@"test_action"];

    NSArray *args = @[@"run-action", @"some-callback-ID"];
    NSDictionary *opt = @{@"test_action":@"%22hi%22"};


    [self.jsDelegate callbackArguments:args withOptions:opt withCompletionHandler:^(NSString *script){
        result = script;
    }];

    XCTAssertEqualObjects(result, @"UAirship.finishAction(null, '\"howdy\"', 'some-callback-ID');", @"resulting script should pass a null error, the result value 'howdy', and the provided callback ID");

    //these are invalid arguments because they are not properly JSON encoded
    opt = @{@"test_action":@"blah"};

    [self.jsDelegate callbackArguments:args withOptions:opt withCompletionHandler:^(NSString *script){
        result = script;
    }];

    XCTAssertEqualObjects(result, @"UAirship.finishAction(new Error('Error decoding arguments: blah'), null, 'some-callback-ID');", @"resulting script should pass an arguments encoding error, a null result value, and the provided callback ID");

    opt = @{@"bogus_action":@"%22hi%22"};

    [self.jsDelegate callbackArguments:args withOptions:opt withCompletionHandler:^(NSString *script){
        result = script;
    }];

    XCTAssertEqualObjects(result, @"UAirship.finishAction(new Error('No action found with name bogus_action, skipping action.'), null, 'some-callback-ID');",@"resulting script should pass an action retrieval error, a null result value, and the provided callback ID");

    args = @[@"run-action"];

    [self.jsDelegate callbackArguments:args withOptions:opt withCompletionHandler:^(NSString *script){
        result = script;
    }];

    XCTAssertTrue(ran, @"the action should have been run");
    XCTAssertNil(result, @"resulting script value should be nil if there is not callback ID");

    [[UAActionRegistrar shared] removeEntryWithName:@"test_action"];
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

    [[UAActionRegistrar shared] registerAction:test name:@"test_action"];
    [[UAActionRegistrar shared] registerAction:alsoTest name:@"also_test_action"];

    NSArray *args = @[@"run-basic-action"];
    //bare argument strings are allowed (and in fact the only allowed argument type) for run-basic-action
    NSDictionary *opt = @{@"test_action":@"hi", @"also_test_action":@"yo"};

    [self.jsDelegate callbackArguments:args withOptions:opt withCompletionHandler:^(NSString *script){
        result = script;
    }];

    XCTAssertNil(result, @"run-basic-action should not produce a script result");
    XCTAssertTrue(ran, @"the action should have run");
    XCTAssertTrue(alsoRan, @"the other action should have run");

    ran = NO;
    alsoRan = NO;

    opt = @{@"bogus_action":@"blah"};

    [self.jsDelegate callbackArguments:args withOptions:opt withCompletionHandler:^(NSString *script){
        result = script;
    }];

    XCTAssertFalse(ran, @"no action should have run");
    XCTAssertFalse(alsoRan, @"no action should have run");

    [[UAActionRegistrar shared] removeEntryWithName:@"test_action"];
    [[UAActionRegistrar shared] removeEntryWithName:@"also_test_action"];
}

@end
