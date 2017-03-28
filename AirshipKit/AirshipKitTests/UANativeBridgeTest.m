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
    [self.jsc evaluateScript:@"_UAirship = {}"];
    [self.jsc evaluateScript:@"window = {}"];

    [self.jsc evaluateScript:self.nativeBridge];
}

- (void)tearDown {
    [self.mockWebView stopMocking];
    [super tearDown];
}


- (void)testRunAction {

    __block NSString *finishResult;
    __block NSString *actionURL;

    // Document body
    self.jsc[@"document"] = @{
                              @"createElement":^(NSString *element){
                                  return @{@"style":@{}};
                              },
                              @"body": @{
                                      @"appendChild":^(id child){
                                          // Capture the action URL
                                          actionURL = child[@"src"];
                                      },
                                      @"removeChild":^(id child){
                                          // no-op
                                      }}};

    // Function invoked by the runAction callback, for verification
    self.jsc[@"finishTest"] = ^(NSString *result){
        finishResult = result;
    };

    // Run the action
    [self.jsc evaluateScript:@"UAirship.runAction('test_action', 'foo', function(err, result) { finishTest(result) })"];

    // Verify the action URL
    XCTAssertEqualObjects(@"uairship://run-action-cb/test_action/%22foo%22/ua-cb-1", actionURL);

    // Finish the action
    [self.jsc evaluateScript:@"UAirship.finishAction(null, 'done', 'ua-cb-1')"];


    // Verify the result
    XCTAssertEqualObjects(@"done", finishResult);
}

@end
