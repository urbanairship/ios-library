/* Copyright 2017 Urban Airship and Contributors */

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
