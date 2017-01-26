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
#import "UIWebView+UAAdditions.h"
#import <OCMock/OCMock.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import "UAirship.h"
#import "UAConfig.h"
#import "UAUser.h"
#import "UAInboxMessage.h"
#import "UAInboxDBManager+Internal.h"


@interface UIWebView_UAAdditionsTest : XCTestCase
@property (strong, nonatomic) UIWebView *webView;
@property (strong, nonatomic) id mockWebView;

@end

@implementation UIWebView_UAAdditionsTest

- (void)setUp {
    [super setUp];

    // Keep a reference to the uninitalized web view
    self.webView = [UIWebView alloc];

    // Create a partial mock so we can expect/verify the category methods
    self.mockWebView = [OCMockObject partialMockForObject:self.webView];
}

- (void)tearDown {
    [super tearDown];

    [self.mockWebView stopMocking];
}

/**
 * Test injectInterfaceOrientation to UIInterfaceOrientationPortrait
 */
- (void)testInjectInterfaceOrientationUIDeviceOrientationPortrait {
    NSString *expectedJS = @"window.__defineGetter__('orientation',function(){return 0;});window.onorientationchange();";

    [[self.mockWebView expect] stringByEvaluatingJavaScriptFromString:expectedJS];
    [self.mockWebView injectInterfaceOrientation:UIInterfaceOrientationPortrait];
    [self.mockWebView verify];
}

/**
 * Test injectInterfaceOrientation to UIInterfaceOrientationLandscapeLeft
 */
- (void)testInjectInterfaceOrientationUIInterfaceOrientationLandscapeLeft {
    NSString *expectedJS = @"window.__defineGetter__('orientation',function(){return -90;});window.onorientationchange();";

    [[self.mockWebView expect] stringByEvaluatingJavaScriptFromString:expectedJS];
    [self.mockWebView injectInterfaceOrientation:UIInterfaceOrientationLandscapeLeft];
    [self.mockWebView verify];
}

/**
 * Test injectInterfaceOrientation to UIInterfaceOrientationLandscapeRight
 */
- (void)testInjectInterfaceOrientationUIInterfaceOrientationLandscapeRight {
    NSString *expectedJS = @"window.__defineGetter__('orientation',function(){return 90;});window.onorientationchange();";

    [[self.mockWebView expect] stringByEvaluatingJavaScriptFromString:expectedJS];
    [self.mockWebView injectInterfaceOrientation:UIInterfaceOrientationLandscapeRight];
    [self.mockWebView verify];
}

/**
 * Test injectInterfaceOrientation to UIInterfaceOrientationPortraitUpsideDown
 */
- (void)testInjectInterfaceOrientationUIInterfaceOrientationPortraitUpsideDown {
    NSString *expectedJS = @"window.__defineGetter__('orientation',function(){return 180;});window.onorientationchange();";

    [[self.mockWebView expect] stringByEvaluatingJavaScriptFromString:expectedJS];
    [self.mockWebView injectInterfaceOrientation:UIInterfaceOrientationPortraitUpsideDown];
    [self.mockWebView verify];
}

@end
