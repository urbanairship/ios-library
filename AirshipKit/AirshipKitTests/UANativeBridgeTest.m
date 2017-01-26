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
#import <OCMock/OCMock.h>

#import <JavaScriptCore/JavaScriptCore.h>
#import "UAWebViewCallData.h"
#import "UAirship.h"

@interface UANativeBridgeTest : XCTestCase
@property (nonatomic, strong) JSContext *jsc;
@property (nonatomic, copy) NSString *nativeBridge;
@property (nonatomic, strong) id mockWebView;

@end

@implementation UANativeBridgeTest

- (void)setUp {
    [super setUp];

    self.mockWebView = [OCMockObject niceMockForClass:[UIWebView class]];

    NSString *path = [[UAirship resources] pathForResource:@"UANativeBridge" ofType:@""];
    self.nativeBridge = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];


    self.jsc = [[JSContext alloc] initWithVirtualMachine:[[JSVirtualMachine alloc] init]];

    //UAirship and window are only used for storage – the former is injected when setting up a UIWebView,
    //and the latter appears to be non-existant in JavaScriptCore
    [self.jsc evaluateScript:@"UAirship = {}"];
    [self.jsc evaluateScript:@"window = {}"];

    [self.jsc evaluateScript:self.nativeBridge];
}

- (void)tearDown {
    [self.mockWebView stopMocking];
    [super tearDown];
}

// Make sure that the functions defined in UANativeBridge are at least parsing
- (void)testNativeBridgeParsed {
    JSValue *value = [self.jsc evaluateScript:@"UAirship.delegateCallURL"];
    XCTAssertFalse([value.toString isEqualToString:@"undefined"], @"UAirship.runAction should not be undefined");
    value = [self.jsc evaluateScript:@"UAirship.invoke"];
    XCTAssertFalse([value.toString isEqualToString:@"undefined"], @"UAirship.invoke should not be undefined");
    value = [self.jsc evaluateScript:@"UAirship.runAction"];
    XCTAssertFalse([value.toString isEqualToString:@"undefined"], @"UAirship.runAction should not be undefined");
    value = [self.jsc evaluateScript:@"UAirship.finishAction"];
    XCTAssertFalse([value.toString isEqualToString:@"undefined"], @"UAirship.finishAction should not be undefined");
}

// UAirship.delegateCallURL is a pure function that builds JS delegate call URLs out of the passed arguments
- (void)testdelegateCallURL {
    JSValue *value = [self.jsc evaluateScript:@"UAirship.delegateCallURL('foo', 3)"];
    XCTAssertEqualObjects(value.toString, @"uairship://foo/3");
    value = [self.jsc evaluateScript:@"UAirship.delegateCallURL('foo', {'baz':'boz'})"];
    XCTAssertEqualObjects(value.toString, @"uairship://foo/?baz=boz");
    value = [self.jsc evaluateScript:@"UAirship.delegateCallURL('foo', 'bar', {'baz':'boz'})"];
    XCTAssertEqualObjects(value.toString, @"uairship://foo/bar?baz=boz");
}

// Test that UAirship.invoke attaches and removes an iframe from the DOM
// note: there appears to be no DOM in JavaScriptCore, but we can fake it for the purposes
// of this test
- (void)testInvoke {

    __block NSString *createdElement;
    __block NSDictionary *appendedChild;
    __block NSDictionary *removedChild;

    NSString *url = @"uairship://foo/bar";

    //this will be the document.body object
    NSDictionary *body = @{@"appendChild":^(id child){
        XCTAssertNil(removedChild, @"child should not have been removed yet");
        appendedChild = child;
    }, @"removeChild":^(id child){
        XCTAssertNotNil(appendedChild, @"child should have first been appended");
        removedChild = child;
    }};

    //set the parent node of the generated child to the body
    NSDictionary *child = @{@"parentNode":body, @"style":@{}};

    //the child, by the time it is appended and removed, should have its src property set to the url
    //and its style should be set to display.none
    NSMutableDictionary *expectedChild = [child mutableCopy];
    [expectedChild setValue:url forKey:@"src"];
    [expectedChild setValue:@{@"display":@"none"} forKey:@"style"];

    //create the dummy document object
    self.jsc[@"document"] = @{@"createElement":^(NSString *element){
        createdElement = element;
        return child;
    }, @"body":body};

    [self.jsc evaluateScript:[NSString stringWithFormat:@"UAirship.invoke('%@')", url]];

    XCTAssertEqualObjects(createdElement, @"iframe", @"iframe should have been created");
    XCTAssertEqualObjects(appendedChild, expectedChild, @"child should have been appended");
    XCTAssertEqualObjects(removedChild, expectedChild, @"child should have been removed");
}

- (void)testRunAction {

    //set to YES if UAirship.invoke is called
    __block BOOL invoked = NO;

    __block NSString *command;
    //set to YES if the callback passed into UAirship.runAction executes
    __block BOOL finished = NO;
    //the result value passed through the runAction callback
    __block NSString *finishResult;

    __weak JSContext *weakContext = self.jsc;

    //mock UAirship.invoke that immediately calls UAirship.finishAction with a result string and the passed callback ID
    self.jsc[@"UAirship"][@"invoke"] = ^(NSString *url) {
        UAWebViewCallData *data = [UAWebViewCallData callDataForURL:[NSURL URLWithString:url] webView:self.mockWebView];
        NSString *cbID = [data.arguments firstObject];
        invoked = YES;
        command = data.name;
        // the call to finishAction should have no error (null), the string "done" (escaped here because it's embedded in an NSString),
        // and the above callback ID (similarly escaped)
        NSString *callFinishAction = [NSString stringWithFormat:@"UAirship.finishAction(null, \"done\", \"%@\")",cbID];
        [weakContext evaluateScript:callFinishAction];
    };

    //function invoked by the runAction callback, for verification
    self.jsc[@"finishTest"] = ^(NSString *result){
        finished = YES;
        finishResult = result;
    };

    [self.jsc evaluateScript:@"\
        try { \
          UAirship.runAction('test_action', 'foo', function(err, result) { \
            finishTest(result)}) \
        } \
        catch(err) { \
          err \
        };"];

    XCTAssertTrue(invoked, @"UAirship.invoke should have been called");
    XCTAssertEqualObjects(command, @"run-action-cb", @"delegate command should be 'run-action-cb'");
    XCTAssertTrue(finished, @"finishTest should have been run in the action callback");

    // Note: we are comparing finishResult and a non-escaped string here, because when the finishResult is passed back across
    // the JavaScriptCore bridge, it ends up becoming a regular NSString
    XCTAssertEqualObjects(finishResult, @"done", @"result of finishTest should be \"done\"");
}

@end
