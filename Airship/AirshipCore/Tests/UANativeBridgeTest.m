/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UANativeBridge+Internal.h"
#import "UAirship+Internal.h"
#import "UANativeBridgeActionHandler+Internal.h"

@interface UANativeBridgeTest : UABaseTest

@property (nonatomic, strong) UANativeBridge *nativeBridge;
@property (nonatomic, strong) id mockWKWebView;
@property (nonatomic, strong) id mockNavigationDelegate;
@property (nonatomic, strong) id mockNativeBridgeDelegate;
@property (nonatomic, strong) id mockNativeBridgeExtensionDelegate;
@property (nonatomic, strong) id mockJavaScriptCommandDelegate;
@property (nonatomic, strong) id mockAirshipJavaScriptCommandDelegate;
@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) id mockActionHandler;
@property (nonatomic, strong) id mockJavaScriptEnvironment;
@property (nonatomic, strong) id mockApplication;
@end

@implementation UANativeBridgeTest

- (void)setUp {
    [super setUp];

    // Mock WKWebView
    self.mockWKWebView = [self mockForClass:[WKWebView class]];

    // Mock Airship
    self.mockAirship = [self mockForClass:[UAirship class]];
    [UAirship setSharedAirship:self.mockAirship];

    // Setup a whitelist
    UAWhitelist *whitelist = [UAWhitelist whitelistWithConfig:self.config];
    [[[self.mockAirship stub] andReturn:whitelist] whitelist];

    // Airship JavaScript command delegate
    self.mockAirshipJavaScriptCommandDelegate = [self mockForProtocol:@protocol(UAJavaScriptCommandDelegate)];
    [[[self.mockAirship stub] andReturn:self.mockAirshipJavaScriptCommandDelegate] javaScriptCommandDelegate];

    // JavaScript environment
    self.mockJavaScriptEnvironment = [self mockForClass:[UAJavaScriptEnvironment class]];
    self.nativeBridge = [UANativeBridge nativeBridgeWithActionHandler:self.mockActionHandler
                                    javaScriptEnvironmentFactoryBlock:^UAJavaScriptEnvironment * _Nonnull{
        return self.mockJavaScriptEnvironment;
    }];

    // Navigation delegate
    self.mockNavigationDelegate = [self mockForProtocol:@protocol(WKNavigationDelegate)];
    self.nativeBridge.forwardNavigationDelegate = self.mockNavigationDelegate;

    // Extension delegate
    self.mockNativeBridgeExtensionDelegate = [self mockForProtocol:@protocol(UANativeBridgeExtensionDelegate)];
    self.nativeBridge.nativeBridgeExtensionDelegate = self.mockNativeBridgeExtensionDelegate;

    // JavaScript command Delegate
    self.mockJavaScriptCommandDelegate = [self mockForProtocol:@protocol(UAJavaScriptCommandDelegate)];
    self.nativeBridge.javaScriptCommandDelegate = self.mockJavaScriptCommandDelegate;

    // NativeBridge delegate
    self.mockNativeBridgeDelegate = [self mockForProtocol:@protocol(UANativeBridgeDelegate)];
    self.nativeBridge.nativeBridgeDelegate = self.mockNativeBridgeDelegate;

    // Mock application
    self.mockApplication = [self mockForClass:[UIApplication class]];
    [[[self.mockApplication stub] andReturn:self.mockApplication] sharedApplication];
}

/**
 * Test webView:didCommitNavigation: forwards its message to the forwardDelegate.
 */
- (void)testDidCommitNavigationForwardDelegate {
    id mockWKNavigation = [self mockForClass:[WKNavigation class]];

    [[self.mockNavigationDelegate expect] webView:self.mockWKWebView didCommitNavigation:mockWKNavigation];
    [self.nativeBridge webView:self.mockWKWebView didCommitNavigation:mockWKNavigation];
    [self.mockNavigationDelegate verify];
}

/**
 * Test webView:didFailNavigation:withError: forwards its message to the forwardDelegate.
 */
- (void)testDidFailNavigationWithErrorForwardDelegate {
    id mockWKNavigation = [self mockForClass:[WKNavigation class]];

    NSError *err = [NSError errorWithDomain:@"wat" code:0 userInfo:nil];
    [[self.mockNavigationDelegate expect] webView:self.mockWKWebView didFailNavigation:mockWKNavigation withError:err];
    [self.nativeBridge webView:self.mockWKWebView didFailNavigation:mockWKNavigation withError:err];
    [self.mockNavigationDelegate verify];
}

/**
 * Test webView:decidePolicyForNavigationAction:decisionHandler: forwards its message to the forwardDelegate.
 */
- (void)testDecidePolicyForNavigationActionDecisionHandlerForwardDelegate {
    id mockWKNavigationAction = [self mockForClass:[WKNavigationAction class]];

    // Stub the navigation delegate to return the response
    [[[self.mockNavigationDelegate expect] andDo:^(NSInvocation *invocation) {
        void (^decisionHandler)(WKNavigationActionPolicy policy) = nil;
        [invocation getArgument:&decisionHandler atIndex:4];
        decisionHandler(WKNavigationActionPolicyCancel);
    }] webView:OCMOCK_ANY decidePolicyForNavigationAction:OCMOCK_ANY decisionHandler:OCMOCK_ANY];

    [self.nativeBridge webView:self.mockWKWebView decidePolicyForNavigationAction:mockWKNavigationAction decisionHandler:^(WKNavigationActionPolicy delegatePolicy) {
        XCTAssertEqual(delegatePolicy, WKNavigationActionPolicyCancel);
    }];

    [self.mockNavigationDelegate verify];
}

/**
 * Test webView:decidePolicyForNavigationAction:decisionHandler: doesn't handles click when navigation is embedded. No delegate.
 */
- (void)testDecidePolicyForNavigationActionDecisionHandlerDoesntHandleClickOnEmbeddedContentNoDelegate {
    // Action request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://www.youtube.com"]];
    NSURL *originatingURL = [NSURL URLWithString:@"https://foo.urbanairship.com/whatever.html"];;

    id mockWKNavigationAction = [self mockForClass:[WKNavigationAction class]];
    [[[mockWKNavigationAction stub] andReturn:request] request];
    [[[mockWKNavigationAction stub] andReturnValue:OCMOCK_VALUE(WKNavigationTypeOther)] navigationType];
    [[[self.mockWKWebView stub] andReturn:originatingURL] URL];

    self.nativeBridge.forwardNavigationDelegate = nil;
    
    [[self.mockApplication reject] openURL:OCMOCK_ANY];
    [self.nativeBridge webView:self.mockWKWebView decidePolicyForNavigationAction:mockWKNavigationAction decisionHandler:^(WKNavigationActionPolicy delegatePolicy) {
        XCTAssertEqual(delegatePolicy, WKNavigationActionPolicyAllow);
    }];

    [self.mockNavigationDelegate verify];
    [self.mockApplication verify];
}

/**
 * Test webView:decidePolicyForNavigationAction:decisionHandler: doesn't handles click when navigation is embedded. Delegate
 */
- (void)testDecidePolicyForNavigationActionDecisionHandlerDoesntHandleClickOnEmbeddedContentDelegate {
    // Action request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://www.youtube.com"]];
    NSURL *originatingURL = [NSURL URLWithString:@"https://foo.urbanairship.com/whatever.html"];;

    id mockWKNavigationAction = [self mockForClass:[WKNavigationAction class]];
    [[[mockWKNavigationAction stub] andReturn:request] request];
    [[[mockWKNavigationAction stub] andReturnValue:OCMOCK_VALUE(WKNavigationTypeOther)] navigationType];
    [[[self.mockWKWebView stub] andReturn:originatingURL] URL];

    [self.nativeBridge webView:self.mockWKWebView decidePolicyForNavigationAction:mockWKNavigationAction decisionHandler:^(WKNavigationActionPolicy delegatePolicy) {
        XCTAssertEqual(delegatePolicy, WKNavigationActionPolicyAllow);
    }];

    [[self.mockApplication reject] openURL:OCMOCK_ANY];

    [self.mockNavigationDelegate verify];
    
    // Stub the navigation delegate to return the response
    [[[self.mockNavigationDelegate expect] andDo:^(NSInvocation *invocation) {
        void (^decisionHandler)(WKNavigationActionPolicy policy) = nil;
        [invocation getArgument:&decisionHandler atIndex:4];
        decisionHandler(WKNavigationActionPolicyAllow);
    }] webView:OCMOCK_ANY decidePolicyForNavigationAction:OCMOCK_ANY decisionHandler:OCMOCK_ANY];

    [self.nativeBridge webView:self.mockWKWebView decidePolicyForNavigationAction:mockWKNavigationAction decisionHandler:^(WKNavigationActionPolicy delegatePolicy) {
        XCTAssertEqual(delegatePolicy, WKNavigationActionPolicyAllow);
    }];

    [self.mockNavigationDelegate verify];
    [self.mockApplication verify];
}

/**
 * Test webView:decidePolicyForNavigationAction:decisionHandler: doesn't handles click when navigation is embedded. No delegate.
 */
- (void)testDecidePolicyForNavigationActionDecisionHandlerHandlesClickOnWKNavigationTypeLinkActivatedNoDelegate {
    // Action request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://www.youtube.com"]];
    NSURL *originatingURL = [NSURL URLWithString:@"https://foo.urbanairship.com/whatever.html"];;

    id mockWKNavigationAction = [self mockForClass:[WKNavigationAction class]];
    [[[mockWKNavigationAction stub] andReturn:request] request];
    [[[mockWKNavigationAction stub] andReturnValue:OCMOCK_VALUE(WKNavigationTypeLinkActivated)] navigationType];
    [[[self.mockWKWebView stub] andReturn:originatingURL] URL];

    self.nativeBridge.forwardNavigationDelegate = nil;
    
    [[self.mockApplication expect] openURL:OCMOCK_ANY];
    [self.nativeBridge webView:self.mockWKWebView decidePolicyForNavigationAction:mockWKNavigationAction decisionHandler:^(WKNavigationActionPolicy delegatePolicy) {
        XCTAssertEqual(delegatePolicy, WKNavigationActionPolicyAllow);
    }];

    [self.mockNavigationDelegate verify];
    [self.mockApplication verify];
}

/**
 * Test webView:decidePolicyForNavigationAction:decisionHandler: doesn't handles click when navigation is embedded. Delegate
 */
- (void)testDecidePolicyForNavigationActionDecisionHandlerHandlesClickOnWKNavigationTypeLinkActivatedDelegate {
    // Action request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://www.youtube.com"]];
    NSURL *originatingURL = [NSURL URLWithString:@"https://foo.urbanairship.com/whatever.html"];;

    id mockWKNavigationAction = [self mockForClass:[WKNavigationAction class]];
    [[[mockWKNavigationAction stub] andReturn:request] request];
    [[[mockWKNavigationAction stub] andReturnValue:OCMOCK_VALUE(WKNavigationTypeLinkActivated)] navigationType];
    [[[self.mockWKWebView stub] andReturn:originatingURL] URL];

    [self.nativeBridge webView:self.mockWKWebView decidePolicyForNavigationAction:mockWKNavigationAction decisionHandler:^(WKNavigationActionPolicy delegatePolicy) {
        XCTAssertEqual(delegatePolicy, WKNavigationActionPolicyAllow);
    }];

    [[self.mockApplication expect] openURL:OCMOCK_ANY];

    [self.mockNavigationDelegate verify];
    
    // Stub the navigation delegate to return the response
    [[[self.mockNavigationDelegate expect] andDo:^(NSInvocation *invocation) {
        void (^decisionHandler)(WKNavigationActionPolicy policy) = nil;
        [invocation getArgument:&decisionHandler atIndex:4];
        decisionHandler(WKNavigationActionPolicyAllow);
    }] webView:OCMOCK_ANY decidePolicyForNavigationAction:OCMOCK_ANY decisionHandler:OCMOCK_ANY];

    [self.nativeBridge webView:self.mockWKWebView decidePolicyForNavigationAction:mockWKNavigationAction decisionHandler:^(WKNavigationActionPolicy delegatePolicy) {
        XCTAssertEqual(delegatePolicy, WKNavigationActionPolicyAllow);
    }];

    [self.mockNavigationDelegate verify];
    [self.mockApplication verify];
    
}
/**
 * Test webView:didFinishNavigation: forwards its message to the forwardDelegate.
 */
- (void)testDidFinishLoadForwardDelegate {
    id mockWKNavigation = [self mockForClass:[WKNavigation class]];
    [[self.mockNavigationDelegate expect] webView:self.mockWKWebView didFinishNavigation:mockWKNavigation];
    [self.nativeBridge webView:self.mockWKWebView didFinishNavigation:mockWKNavigation];
    [self.mockNavigationDelegate verify];
}

/**
 * Test webView:decidePolicyForNavigationAction:decisionHandler: forwards action commands to the action handler.
 */
- (void)testShouldStartLoadRunsActions {
    // Action request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"uairship://run-basic-actions?test_action=hi"]];
    NSURL *originatingURL = [NSURL URLWithString:@"https://foo.urbanairship.com/whatever.html"];;

    id mockWKNavigationAction = [self mockForClass:[WKNavigationAction class]];
    [[[mockWKNavigationAction stub] andReturn:request] request];
    [[[self.mockWKWebView stub] andReturn:originatingURL] URL];

    // Expect the js delegate to be called with the correct command
    [[self.mockActionHandler expect] runActionsForCommand:[OCMArg checkWithBlock:^BOOL(id obj) { return [((UAJavaScriptCommand *)obj).URL isEqual:request.URL]; }]
                                                 metadata:@{}
                                        completionHandler:OCMOCK_ANY];

    [self.nativeBridge webView:self.mockWKWebView decidePolicyForNavigationAction:mockWKNavigationAction decisionHandler:^(WKNavigationActionPolicy delegatePolicy) {
        XCTAssertEqual(delegatePolicy, WKNavigationActionPolicyCancel);
    }];

    [self.mockActionHandler verify];
}

/**
 * Test providing action metadata with the extension delegate.
 */
- (void)testRunActionsCustomMetadata {
    // Action request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"uairship://run-basic-actions?test_action=hi"]];
    NSURL *originatingURL = [NSURL URLWithString:@"https://foo.urbanairship.com/whatever.html"];;

    id mockWKNavigationAction = [self mockForClass:[WKNavigationAction class]];
    [[[mockWKNavigationAction stub] andReturn:request] request];
    [[[self.mockWKWebView stub] andReturn:originatingURL] URL];

    NSDictionary *customMetadata = @{ @"cool": @"story" };

    [[[self.mockNativeBridgeExtensionDelegate stub] andReturn:customMetadata] actionsMetadataForCommand:OCMOCK_ANY webView:self.mockWKWebView];

    // Expect the js delegate to be called with the correct command
    [[self.mockActionHandler expect] runActionsForCommand:[OCMArg checkWithBlock:^BOOL(id obj) { return [((UAJavaScriptCommand *)obj).URL isEqual:request.URL]; }]
                                                 metadata:customMetadata
                                        completionHandler:OCMOCK_ANY];

    [self.nativeBridge webView:self.mockWKWebView decidePolicyForNavigationAction:mockWKNavigationAction decisionHandler:^(WKNavigationActionPolicy delegatePolicy) {
        XCTAssertEqual(delegatePolicy, WKNavigationActionPolicyCancel);
    }];

    [self.mockActionHandler verify];
}

/**
 * Test webView:shouldStartLoadWithRequest:navigationType: does not forward action commands if the URL is not whitelisted.
 */
- (void)testShouldStartLoadRejectsActionRunsNotWhitelisted {
    // Action request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"uairship://run-basic-actions?test_action=hi"]];
    NSURL *originatingURL = [NSURL URLWithString:@"https://foo.notwhitelisted.com/whatever.html"];;

    id mockWKNavigationAction = [self mockForClass:[WKNavigationAction class]];
    [[[mockWKNavigationAction stub] andReturn:request] request];
    [[[self.mockWKWebView stub] andReturn:originatingURL] URL];

    // Reject any calls to the JS Delegate
    [[self.mockActionHandler reject] runActionsForCommand:OCMOCK_ANY metadata:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [self.nativeBridge webView:self.mockWKWebView decidePolicyForNavigationAction:mockWKNavigationAction decisionHandler:^(WKNavigationActionPolicy delegatePolicy) {
        XCTAssertEqual(delegatePolicy, WKNavigationActionPolicyAllow);
    }];

    [self.mockActionHandler verify];
}

/**
 * Test webView:shouldStartLoadWithRequest:navigationType: forwards custom uairship:// to the JavaScript command delegate.
 */
- (void)testJavaScriptCommandDelegate {
    // Airship JavaScript request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"uairship://whatever"]];
    NSURL *originatingURL = [NSURL URLWithString:@"https://foo.urbanairship.com/whatever.html"];;

    id mockWKNavigationAction = [self mockForClass:[WKNavigationAction class]];
    [[[mockWKNavigationAction stub] andReturn:request] request];
    [[[self.mockWKWebView stub] andReturn:originatingURL] URL];

    [[[self.mockJavaScriptCommandDelegate expect] andReturnValue:@(YES)] performCommand:[OCMArg checkWithBlock:^BOOL(id obj) {
        return [((UAJavaScriptCommand *)obj).URL isEqual:request.URL];
    }] webView:self.mockWKWebView];

    [self.nativeBridge webView:self.mockWKWebView decidePolicyForNavigationAction:mockWKNavigationAction decisionHandler:^(WKNavigationActionPolicy delegatePolicy) {
       XCTAssertEqual(delegatePolicy, WKNavigationActionPolicyCancel);
    }];

    [self.mockJavaScriptCommandDelegate verify];
}

/**
 * Test webView:shouldStartLoadWithRequest:navigationType: forwards custom uairship:// to the Airship JavaScript command delegate.
 */
- (void)testAirshipJavaScriptCommandDelegate {
    // Airship JavaScript request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"uairship://whatever"]];
    NSURL *originatingURL = [NSURL URLWithString:@"https://foo.urbanairship.com/whatever.html"];;

    id mockWKNavigationAction = [self mockForClass:[WKNavigationAction class]];
    [[[mockWKNavigationAction stub] andReturn:request] request];
    [[[self.mockWKWebView stub] andReturn:originatingURL] URL];

    [[[self.mockJavaScriptCommandDelegate expect] andReturnValue:@(NO)] performCommand:[OCMArg checkWithBlock:^BOOL(id obj) {
        return [((UAJavaScriptCommand *)obj).URL isEqual:request.URL];
    }] webView:self.mockWKWebView];

    [[[self.mockAirshipJavaScriptCommandDelegate expect] andReturnValue:@(YES)] performCommand:[OCMArg checkWithBlock:^BOOL(id obj) {
        return [((UAJavaScriptCommand *)obj).URL isEqual:request.URL];
    }] webView:self.mockWKWebView];


    [self.nativeBridge webView:self.mockWKWebView decidePolicyForNavigationAction:mockWKNavigationAction decisionHandler:^(WKNavigationActionPolicy delegatePolicy) {
       XCTAssertEqual(delegatePolicy, WKNavigationActionPolicyCancel);
    }];

    [self.mockAirshipJavaScriptCommandDelegate verify];
    [self.mockJavaScriptCommandDelegate verify];
}

/**
 * Test webView:shouldStartLoadWithRequest:navigationType: forwards custom uairship://close to the native bridge delegate.
 */
- (void)testCloseCommand {
    // Airship JavaScript request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"uairship://close"]];
    NSURL *originatingURL = [NSURL URLWithString:@"https://foo.urbanairship.com/whatever.html"];;

    id mockWKNavigationAction = [self mockForClass:[WKNavigationAction class]];
    [[[mockWKNavigationAction stub] andReturn:request] request];
    [[[self.mockWKWebView stub] andReturn:originatingURL] URL];

    [[self.mockNativeBridgeDelegate expect] close];

    [self.nativeBridge webView:self.mockWKWebView decidePolicyForNavigationAction:mockWKNavigationAction decisionHandler:^(WKNavigationActionPolicy delegatePolicy) {
       XCTAssertEqual(delegatePolicy, WKNavigationActionPolicyCancel);
    }];

    [self.mockNativeBridgeDelegate verify];
}

/**
 * Test webView:didFinishNavigation: injects the Airship JavaScript environment.
 */
- (void)testInjectJavaScriptEnvironment {
    NSURL *originatingURL = [NSURL URLWithString:@"https://foo.urbanairship.com/whatever.html"];;
    [[[self.mockWKWebView stub] andReturn:originatingURL] URL];
    id mockWKNavigation = [self mockForClass:[WKNavigation class]];

    [[[self.mockJavaScriptEnvironment stub] andReturn:@"script!"] build];
    [[self.mockWKWebView expect] evaluateJavaScript:@"script!" completionHandler:OCMOCK_ANY];

    [self.nativeBridge webView:self.mockWKWebView didFinishNavigation:mockWKNavigation];

    [self.mockWKWebView verify];
}

/**
 * Test extending the JavaScript environment with the native bridge extension delegate.
 */
- (void)testExtendingJavaScriptEnvironment {
    NSURL *originatingURL = [NSURL URLWithString:@"https://foo.urbanairship.com/whatever.html"];;
    [[[self.mockWKWebView stub] andReturn:originatingURL] URL];
    id mockWKNavigation = [self mockForClass:[WKNavigation class]];

    [[[self.mockNativeBridgeExtensionDelegate stub] andDo:^(NSInvocation *invocation) {
        [[[self.mockJavaScriptEnvironment stub] andReturn:@"extended script!"] build];
    }] extendJavaScriptEnvironment:self.mockJavaScriptEnvironment webView:self.mockWKWebView];

    [[self.mockWKWebView expect] evaluateJavaScript:@"extended script!" completionHandler:OCMOCK_ANY];

    [self.nativeBridge webView:self.mockWKWebView didFinishNavigation:mockWKNavigation];

    [self.mockWKWebView verify];
}

/**
 * Test webView:didFinishNavigation: does not inject the Airship JavaScript environment when the URL is not whitelisted.
 */
- (void)testDidFinishNotWhitelisted {
    NSURL *url = [NSURL URLWithString:@"https://foo.notwhitelisted.com/whatever.html"];
    [[[self.mockWKWebView stub] andReturn:url] URL];
    id mockWKNavigation = [self mockForClass:[WKNavigation class]];

    // Capture the js environment string
    [[[self.mockWKWebView stub] andDo:^(NSInvocation *invocation) {
        XCTFail(@"No JS should have been injected");
    }] evaluateJavaScript:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [self.nativeBridge webView:self.mockWKWebView didFinishNavigation:mockWKNavigation];
}

@end
