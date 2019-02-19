/* Copyright 2010-2019 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UIWebView+UAAdditions.h"
#import <JavaScriptCore/JavaScriptCore.h>
#import "UAirship.h"
#import "UAConfig.h"
#import "UAUser.h"

@interface UIWebView_UAAdditionsTest : UABaseTest
@property (strong, nonatomic) UIWebView *webView;
@property (strong, nonatomic) id mockWebView;

@end

@implementation UIWebView_UAAdditionsTest

- (void)setUp {
    [super setUp];

    // Keep a reference to the uninitalized web view
    self.webView = [UIWebView alloc];

    // Create a partial mock so we can expect/verify the category methods
    self.mockWebView = [self partialMockForObject:self.webView];
}

- (void)tearDown {
    [self.mockWebView stopMocking];
    [super tearDown];
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
