/*
 Copyright 2009-2014 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

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
#import "UIWebView+UAAdditions.h"
#import <OCMock/OCMock.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import "UAUser.h"
#import "UAInboxMessage.h"
#import "UAInboxDBManager+Internal.h"


@interface UIWebView_UAAdditionsTest : XCTestCase
@property(strong, nonatomic) id webView;
@property(strong, nonatomic) id mockWebView;
@property(strong, nonatomic) id mockUIDevice;
@property(strong, nonatomic) id mockUAUser;

@property(nonatomic, strong) JSContext *jsc;

@end

@implementation UIWebView_UAAdditionsTest

- (void)setUp {
    [super setUp];

    // Keep a reference to the uninitalized web view
    self.webView = [UIWebView alloc];

    // Create a partial mock so we can expect/verify the category methods
    self.mockWebView = [OCMockObject partialMockForObject:self.webView];

    self.jsc = [[JSContext alloc] initWithVirtualMachine:[[JSVirtualMachine alloc] init]];
    [self.jsc evaluateScript:@"window = {}"];

    // Mock UAUser
    self.mockUAUser = [OCMockObject niceMockForClass:[UAUser class]];
    [[[self.mockUAUser stub] andReturn:self.mockUAUser] defaultUser];

    // Mock UIDevice
    self.mockUIDevice = [OCMockObject niceMockForClass:[UIDevice class]];
    [[[self.mockUIDevice stub] andReturn:self.mockUIDevice] currentDevice];
}

- (void)tearDown {
    [super tearDown];

    [self.mockWebView stopMocking];
    [self.mockUIDevice stopMocking];
    [self.mockUAUser stopMocking];
}

/**
 * Test injecting the view port fix
 */
- (void)testInjectViewPortFix {
    NSString *expectedJS = @"var metaTag = document.createElement('meta');"
    "metaTag.name = 'viewport';"
    "metaTag.content = 'width=device-width; user-scalable=no;';";

    [[self.mockWebView expect] stringByEvaluatingJavaScriptFromString:expectedJS];

    [self.mockWebView injectViewportFix];

    [self.mockWebView verify];
}

/**
 * Test willRotateToInterfaceOrientation to UIInterfaceOrientationPortrait
 */
- (void)testWillRotateToInterfaceOrientationUIDeviceOrientationPortrait {
    NSString *expectedJS = @"window.__defineGetter__('orientation',function(){return 0;});window.onorientationchange();";

    [[self.mockWebView expect] stringByEvaluatingJavaScriptFromString:expectedJS];
    [self.mockWebView willRotateToInterfaceOrientation:UIInterfaceOrientationPortrait];
    [self.mockWebView verify];
}

/**
 * Test willRotateToInterfaceOrientation to UIInterfaceOrientationLandscapeLeft
 */
- (void)testWillRotateToInterfaceOrientationUIInterfaceOrientationLandscapeLeft {
    NSString *expectedJS = @"window.__defineGetter__('orientation',function(){return -90;});window.onorientationchange();";

    [[self.mockWebView expect] stringByEvaluatingJavaScriptFromString:expectedJS];
    [self.mockWebView willRotateToInterfaceOrientation:UIInterfaceOrientationLandscapeLeft];
    [self.mockWebView verify];
}

/**
 * Test willRotateToInterfaceOrientation to UIInterfaceOrientationLandscapeRight
 */
- (void)testWillRotateToInterfaceOrientationUIInterfaceOrientationLandscapeRight {
    NSString *expectedJS = @"window.__defineGetter__('orientation',function(){return 90;});window.onorientationchange();";

    [[self.mockWebView expect] stringByEvaluatingJavaScriptFromString:expectedJS];
    [self.mockWebView willRotateToInterfaceOrientation:UIInterfaceOrientationLandscapeRight];
    [self.mockWebView verify];
}

/**
 * Test willRotateToInterfaceOrientation to UIInterfaceOrientationPortraitUpsideDown
 */
- (void)testWillRotateToInterfaceOrientationUIInterfaceOrientationPortraitUpsideDown {
    NSString *expectedJS = @"window.__defineGetter__('orientation',function(){return 180;});window.onorientationchange();";

    [[self.mockWebView expect] stringByEvaluatingJavaScriptFromString:expectedJS];
    [self.mockWebView willRotateToInterfaceOrientation:UIInterfaceOrientationPortraitUpsideDown];
    [self.mockWebView verify];
}

/**
 * Test populateJavascriptEnvironment without a message
 */
- (void)testPopulateJavascriptEnvironment {
    [[[self.mockUAUser stub] andReturn:@"user name"] username];
    [[[self.mockUIDevice stub] andReturn:@"device model"] model];

    __block NSString *js;

    // Capture the js environment string
    [[[self.mockWebView stub] andDo:^(NSInvocation *invocation) {
        [invocation getArgument:&js atIndex:2];
        [invocation setReturnValue:&js];
    }] stringByEvaluatingJavaScriptFromString:[OCMArg any]];

    [self.mockWebView populateJavascriptEnvironment];

    XCTAssertNotNil(js, "Javascript environment was not populated");

    [self.jsc evaluateScript:js];

    // Verify device model
    XCTAssertEqualObjects(@"device model", [self.jsc evaluateScript:@"UAirship.devicemodel"].toString);
    XCTAssertEqualObjects(@"device model", [self.jsc evaluateScript:@"UAirship.getDeviceModel()"].toString);

    // Verify user id
    XCTAssertEqualObjects(@"user name", [self.jsc evaluateScript:@"UAirship.userID"].toString);
    XCTAssertEqualObjects(@"user name", [self.jsc evaluateScript:@"UAirship.getUserId()"].toString);

    // Verify message id is null
    XCTAssertTrue([self.jsc evaluateScript:@"UAirship.getMessageId()"].isNull);
    XCTAssertTrue([self.jsc evaluateScript:@"UAirship.messageID"].isNull);

    // Verify message title is null
    XCTAssertTrue([self.jsc evaluateScript:@"UAirship.getMessageTitle()"].isNull);
    XCTAssertTrue([self.jsc evaluateScript:@"UAirship.messageTitle"].isNull);

    // Verify message send date is null
    XCTAssertTrue([self.jsc evaluateScript:@"UAirship.getMessageSentDate()"].isNull);
    XCTAssertTrue([self.jsc evaluateScript:@"UAirship.messageSentDate"].isNull);

    // Verify message send date ms is -1
    XCTAssertEqualObjects(@-1, [self.jsc evaluateScript:@"UAirship.getMessageSentDateMS()"].toNumber);
    XCTAssertEqualObjects(@-1, [self.jsc evaluateScript:@"UAirship.messageSentDateMS"].toNumber);


    // Verify native bridge methods are not undefined
    XCTAssertFalse([self.jsc evaluateScript:@"UAirship.delegateCallURL"].isUndefined);
    XCTAssertFalse([self.jsc evaluateScript:@"UAirship.invoke"].isUndefined);
    XCTAssertFalse([self.jsc evaluateScript:@"UAirship.runAction"].isUndefined);
    XCTAssertFalse([self.jsc evaluateScript:@"UAirship.finishAction"].isUndefined);
}


/**
 * Test populateJavascriptEnvironment with a message
 */
- (void)testPopulateJavascriptEnvironmentWithMessage {

    // Create an actual message because NSManagedObjects and OCMock are not friends.
    NSDictionary *messageDefintion = @{@"message_id": @"messageID",
                                       @"title": @"messageTitle",
                                       @"content_type": @"someContentType",
                                       @"extra": @{@"someKey":@"someValue"},
                                       @"message_body_url": @"http://someMessageBodyUrl",
                                       @"message_url": @"http://someMessageUrl",
                                       @"unread": @"0",
                                       @"message_sent": @"2013-08-13 00:16:22" };

    UAInboxMessage *message = [[UAInboxDBManager shared] addMessageFromDictionary:messageDefintion];

    __block NSString *js;

    // Capture the js environment string
    [[[self.mockWebView stub] andDo:^(NSInvocation *invocation) {
        [invocation getArgument:&js atIndex:2];
        [invocation setReturnValue:&js];
    }] stringByEvaluatingJavaScriptFromString:[OCMArg any]];

    [self.mockWebView populateJavascriptEnvironment:message];

    XCTAssertNotNil(js, "Javascript environment was not populated");

    [self.jsc evaluateScript:js];

    // Verify message id
    XCTAssertEqualObjects(@"messageID", [self.jsc evaluateScript:@"UAirship.getMessageId()"].toString);
    XCTAssertEqualObjects(@"messageID", [self.jsc evaluateScript:@"UAirship.messageID"].toString);

    // Verify message title
    XCTAssertEqualObjects(@"messageTitle", [self.jsc evaluateScript:@"UAirship.getMessageTitle()"].toString);
    XCTAssertEqualObjects(@"messageTitle", [self.jsc evaluateScript:@"UAirship.messageTitle"].toString);

    // Verify message send date
    XCTAssertEqualObjects(@"2013-08-13 00:16:22", [self.jsc evaluateScript:@"UAirship.getMessageSentDate()"].toString);
    XCTAssertEqualObjects(@"2013-08-13 00:16:22", [self.jsc evaluateScript:@"UAirship.messageSentDate"].toString);

    // Verify message send date ms
    XCTAssertEqualObjects(@1376352982000, [self.jsc evaluateScript:@"UAirship.getMessageSentDateMS()"].toNumber);
    XCTAssertEqualObjects(@1376352982000, [self.jsc evaluateScript:@"UAirship.messageSentDateMS"].toNumber);
}

@end
