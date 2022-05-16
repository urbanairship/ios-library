/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "AirshipTests-Swift.h"

@import AirshipCore;

@interface UANativeBridgeTest : UAAirshipBaseTest

@property (nonatomic, strong) UANativeBridge *nativeBridge;
@property (nonatomic, strong) id mockWKWebView;
@property (nonatomic, strong) id mockNavigationDelegate;
@property (nonatomic, strong) id mockNativeBridgeDelegate;
@property (nonatomic, strong) id mockNativeBridgeExtensionDelegate;
@property (nonatomic, strong) id mockJavaScriptCommandDelegate;
@property (nonatomic, strong) id mockAirshipJavaScriptCommandDelegate;
@property (nonatomic, strong) UATestAirshipInstance *airship;
@property (nonatomic, strong) id mockContact;
@property (nonatomic, strong) id mockActionHandler;
@property (nonatomic, strong) id mockJavaScriptEnvironment;
@property (nonatomic, strong) id mockApplication;
@end

@implementation UANativeBridgeTest

- (void)setUp {
    [super setUp];

    // Mock WKWebView
    self.mockWKWebView = [self mockForClass:[WKWebView class]];

    // Setup a URL allow list
    UAURLAllowList *URLAllowList = [UAURLAllowList allowListWithConfig:self.config];

    self.mockActionHandler = [self mockForProtocol:@protocol(UANativeBridgeActionHandlerProtocol)];
    
    // Airship JavaScript command delegate
    self.mockAirshipJavaScriptCommandDelegate = [self mockForProtocol:@protocol(UAJavaScriptCommandDelegate)];

    // JavaScript environment
    self.mockJavaScriptEnvironment = [self mockForProtocol:@protocol(UAJavaScriptEnvironmentProtocol)];
    self.nativeBridge = [[UANativeBridge alloc] initWithActionHandler:self.mockActionHandler
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
    
    self.mockContact = [self mockForClass:[UAContact class]];

    // Mock application
    self.mockApplication = [self mockForClass:[UIApplication class]];
    [[[self.mockApplication stub] andReturn:self.mockApplication] sharedApplication];
    
    self.airship = [[UATestAirshipInstance alloc] init];
    self.airship.components = @[self.mockContact];
    self.airship.urlAllowList = URLAllowList;
    self.airship.javaScriptCommandDelegate = self.mockAirshipJavaScriptCommandDelegate;
    [self.airship makeShared];
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
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://www.youtube.com"]];
   
    [[[mockWKNavigationAction stub] andReturn:request] request];
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
    id mockWKFrameInfo = [self mockForClass:[WKFrameInfo class]];
    [[[mockWKNavigationAction stub] andReturn:mockWKFrameInfo] targetFrame];
    [[[self.mockWKWebView stub] andReturn:originatingURL] URL];

    self.nativeBridge.forwardNavigationDelegate = nil;
    
    [[self.mockApplication reject] openURL:OCMOCK_ANY options:OCMOCK_ANY completionHandler:OCMOCK_ANY];

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
    id mockWKFrameInfo = [self mockForClass:[WKFrameInfo class]];
    [[[mockWKNavigationAction stub] andReturn:mockWKFrameInfo] targetFrame];
    [[[self.mockWKWebView stub] andReturn:originatingURL] URL];

    [self.nativeBridge webView:self.mockWKWebView decidePolicyForNavigationAction:mockWKNavigationAction decisionHandler:^(WKNavigationActionPolicy delegatePolicy) {
        XCTAssertEqual(delegatePolicy, WKNavigationActionPolicyAllow);
    }];

    [[self.mockApplication reject] openURL:OCMOCK_ANY options:OCMOCK_ANY completionHandler:OCMOCK_ANY];

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
 * Test webView:decidePolicyForNavigationAction:decisionHandler: handles click when navigation is embedded. No delegate.
 */
- (void)testDecidePolicyForNavigationActionDecisionHandlerHandlesClickOnWKNavigationTypeLinkActivatedNoDelegate {
    // Action request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://www.youtube.com"]];
    NSURL *originatingURL = [NSURL URLWithString:@"https://foo.urbanairship.com/whatever.html"];;

    id mockWKNavigationAction = [self mockForClass:[WKNavigationAction class]];
    [[[mockWKNavigationAction stub] andReturn:request] request];
    [[[mockWKNavigationAction stub] andReturnValue:OCMOCK_VALUE(WKNavigationTypeLinkActivated)] navigationType];
    id mockWKFrameInfo = [self mockForClass:[WKFrameInfo class]];
    [[[mockWKNavigationAction stub] andReturn:mockWKFrameInfo] targetFrame];
    [[[self.mockWKWebView stub] andReturn:originatingURL] URL];

    self.nativeBridge.forwardNavigationDelegate = nil;
    
    [[[self.mockApplication expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^completionHandler)(BOOL) = (__bridge void(^)(BOOL))arg;
        completionHandler(YES);
    }] openURL:OCMOCK_ANY options:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    
    [self.nativeBridge webView:self.mockWKWebView decidePolicyForNavigationAction:mockWKNavigationAction decisionHandler:^(WKNavigationActionPolicy delegatePolicy) {
        XCTAssertEqual(delegatePolicy, WKNavigationActionPolicyCancel);
    }];

    [self.mockNavigationDelegate verify];
    [self.mockApplication verify];
}

/**
 * Test webView:decidePolicyForNavigationAction:decisionHandler: handles click when navigation is embedded. Delegate
 */
- (void)testDecidePolicyForNavigationActionDecisionHandlerHandlesClickOnWKNavigationTypeLinkActivatedDelegate {
    // Action request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://www.youtube.com"]];
    NSURL *originatingURL = [NSURL URLWithString:@"https://foo.urbanairship.com/whatever.html"];;

    id mockWKNavigationAction = [self mockForClass:[WKNavigationAction class]];
    [[[mockWKNavigationAction stub] andReturn:request] request];
    [[[mockWKNavigationAction stub] andReturnValue:OCMOCK_VALUE(WKNavigationTypeLinkActivated)] navigationType];
    id mockWKFrameInfo = [self mockForClass:[WKFrameInfo class]];
    [[[mockWKNavigationAction stub] andReturn:mockWKFrameInfo] targetFrame];
    [[[self.mockWKWebView stub] andReturn:originatingURL] URL];

    [self.nativeBridge webView:self.mockWKWebView decidePolicyForNavigationAction:mockWKNavigationAction decisionHandler:^(WKNavigationActionPolicy delegatePolicy) {
        XCTAssertEqual(delegatePolicy, WKNavigationActionPolicyAllow);
    }];

    [[[self.mockApplication expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^completionHandler)(BOOL) = (__bridge void(^)(BOOL))arg;
        completionHandler(YES);
    }] openURL:OCMOCK_ANY options:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    
    
    [self.mockNavigationDelegate verify];
    
    // Stub the navigation delegate to return the response
    [[[self.mockNavigationDelegate expect] andDo:^(NSInvocation *invocation) {
        void (^decisionHandler)(WKNavigationActionPolicy policy) = nil;
        [invocation getArgument:&decisionHandler atIndex:4];
        decisionHandler(WKNavigationActionPolicyAllow);
    }] webView:OCMOCK_ANY decidePolicyForNavigationAction:OCMOCK_ANY decisionHandler:OCMOCK_ANY];

    [self.nativeBridge webView:self.mockWKWebView decidePolicyForNavigationAction:mockWKNavigationAction decisionHandler:^(WKNavigationActionPolicy delegatePolicy) {
        XCTAssertEqual(delegatePolicy, WKNavigationActionPolicyCancel);
    }];

    [self.mockNavigationDelegate verify];
    [self.mockApplication verify];
    
}

- (void)testDecisionHandlerMultipleCalls  {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://www.youtube.com"]];
    NSURL *originatingURL = [NSURL URLWithString:@"https://foo.urbanairship.com/whatever.html"];;

    id mockWKNavigationAction = [self mockForClass:[WKNavigationAction class]];
    [[[mockWKNavigationAction stub] andReturn:request] request];
    [[[mockWKNavigationAction stub] andReturnValue:OCMOCK_VALUE(WKNavigationTypeOther)] navigationType];
    id mockWKFrameInfo = [self mockForClass:[WKFrameInfo class]];
    [[[mockWKNavigationAction stub] andReturn:mockWKFrameInfo] targetFrame];
    [[[self.mockWKWebView stub] andReturn:originatingURL] URL];

    // Stub the navigation delegate to return the response
    [[[self.mockNavigationDelegate expect] andDo:^(NSInvocation *invocation) {
        void (^decisionHandler)(WKNavigationActionPolicy policy) = nil;
        [invocation getArgument:&decisionHandler atIndex:4];
        decisionHandler(WKNavigationActionPolicyAllow);
    }] webView:OCMOCK_ANY decidePolicyForNavigationAction:OCMOCK_ANY decisionHandler:OCMOCK_ANY];

    

    XCTestExpectation *finished = [self expectationWithDescription:@"Fetched frequency checker"];
    [self.nativeBridge webView:self.mockWKWebView decidePolicyForNavigationAction:mockWKNavigationAction decisionHandler:^(WKNavigationActionPolicy delegatePolicy) {
        [finished fulfill];
    }];
    
    [self waitForTestExpectations];
}

/**
 * Test webView:decidePolicyForNavigationAction:decisionHandler: handles click to new target window when navigation is embedded. No delegate.
 */
- (void)testDecidePolicyForNavigationActionDecisionHandlerHandlesClickOnWKNavigationTypeLinkActivatedNewTargetNoDelegate {
    // Action request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://www.blah.blah"]];
    NSURL *originatingURL = [NSURL URLWithString:@"https://foo.urbanairship.com/whatever.html"];;

    id mockWKNavigationAction = [self mockForClass:[WKNavigationAction class]];
    [[[mockWKNavigationAction stub] andReturn:request] request];
    [[[mockWKNavigationAction stub] andReturnValue:OCMOCK_VALUE(WKNavigationTypeLinkActivated)] navigationType];
    [[[mockWKNavigationAction stub] andReturn:nil] targetFrame];
    [[[self.mockWKWebView stub] andReturn:originatingURL] URL];

    self.nativeBridge.forwardNavigationDelegate = nil;
    
    XCTestExpectation *testExpectation = [self expectationWithDescription:@"decision handler called"];
    
    [[[self.mockApplication expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^completionHandler)(BOOL) = (__bridge void(^)(BOOL))arg;
        completionHandler(YES);
    }] openURL:OCMOCK_ANY options:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [self.nativeBridge webView:self.mockWKWebView decidePolicyForNavigationAction:mockWKNavigationAction decisionHandler:^(WKNavigationActionPolicy delegatePolicy) {
        XCTAssertEqual(delegatePolicy, WKNavigationActionPolicyCancel);
        [testExpectation fulfill];
    }];

    [self waitForTestExpectations];
    
    [self.mockNavigationDelegate verify];
    [self.mockApplication verify];
}

/**
 * Test webView:decidePolicyForNavigationAction:decisionHandler: doesn't handle click to new target window when navigation is embedded. Delegate
 */
- (void)testDecidePolicyForNavigationActionDecisionHandlerDoesntHandleClickOnWKNavigationTypeLinkActivatedNewTargetDelegate {
    // Action request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://www.blah.blah"]];
    NSURL *originatingURL = [NSURL URLWithString:@"https://foo.urbanairship.com/whatever.html"];;

    id mockWKNavigationAction = [self mockForClass:[WKNavigationAction class]];
    [[[mockWKNavigationAction stub] andReturn:request] request];
    [[[mockWKNavigationAction stub] andReturnValue:OCMOCK_VALUE(WKNavigationTypeLinkActivated)] navigationType];
    id mockWKFrameInfo = [self mockForClass:[WKFrameInfo class]];
    [[[mockWKNavigationAction stub] andReturn:mockWKFrameInfo] targetFrame];
    [[[self.mockWKWebView stub] andReturn:originatingURL] URL];

    [self.nativeBridge webView:self.mockWKWebView decidePolicyForNavigationAction:mockWKNavigationAction decisionHandler:^(WKNavigationActionPolicy delegatePolicy) {
        XCTAssertEqual(delegatePolicy, WKNavigationActionPolicyAllow);
    }];

    [[self.mockApplication reject] openURL:OCMOCK_ANY options:OCMOCK_ANY completionHandler:OCMOCK_ANY];

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
    id mockWKFrameInfo = [self mockForClass:[WKFrameInfo class]];
    [[[mockWKNavigationAction stub] andReturn:mockWKFrameInfo] targetFrame];
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
    id mockWKFrameInfo = [self mockForClass:[WKFrameInfo class]];
    [[[mockWKNavigationAction stub] andReturn:mockWKFrameInfo] targetFrame];
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
 * Test providing no action metadata.
 */
- (void)testRunActionsNoMetadataForCommand {
    // Action request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"uairship://run-basic-actions?test_action=hi"]];
    NSURL *originatingURL = [NSURL URLWithString:@"https://foo.urbanairship.com/whatever.html"];;

    id mockWKNavigationAction = [self mockForClass:[WKNavigationAction class]];
    [[[mockWKNavigationAction stub] andReturn:request] request];
    id mockWKFrameInfo = [self mockForClass:[WKFrameInfo class]];
    [[[mockWKNavigationAction stub] andReturn:mockWKFrameInfo] targetFrame];
    [[[self.mockWKWebView stub] andReturn:originatingURL] URL];
    self.nativeBridge.nativeBridgeExtensionDelegate = nil;

    // Expect the js delegate to be called with the correct command
    [[self.mockActionHandler expect] runActionsForCommand:[OCMArg checkWithBlock:^BOOL(id obj) { return [((UAJavaScriptCommand *)obj).URL isEqual:request.URL]; }]
                                                 metadata:nil
                                        completionHandler:OCMOCK_ANY];

    [self.nativeBridge webView:self.mockWKWebView decidePolicyForNavigationAction:mockWKNavigationAction decisionHandler:^(WKNavigationActionPolicy delegatePolicy) {
        XCTAssertEqual(delegatePolicy, WKNavigationActionPolicyCancel);
    }];

    [self.mockActionHandler verify];
}

/**
 * Test webView:shouldStartLoadWithRequest:navigationType: does not forward action commands if the URL is not allowed.
 */
- (void)testShouldStartLoadRejectsActionRunsNotAllowed {
    // Action request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"uairship://run-basic-actions?test_action=hi"]];
    NSURL *originatingURL = [NSURL URLWithString:@"https://foo.notAllowed.com/whatever.html"];;

    id mockWKNavigationAction = [self mockForClass:[WKNavigationAction class]];
    [[[mockWKNavigationAction stub] andReturn:request] request];
    id mockWKFrameInfo = [self mockForClass:[WKFrameInfo class]];
    [[[mockWKNavigationAction stub] andReturn:mockWKFrameInfo] targetFrame];
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
    id mockWKFrameInfo = [self mockForClass:[WKFrameInfo class]];
    [[[mockWKNavigationAction stub] andReturn:mockWKFrameInfo] targetFrame];
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
    id mockWKFrameInfo = [self mockForClass:[WKFrameInfo class]];
    [[[mockWKNavigationAction stub] andReturn:mockWKFrameInfo] targetFrame];
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
    id mockWKFrameInfo = [self mockForClass:[WKFrameInfo class]];
    [[[mockWKNavigationAction stub] andReturn:mockWKFrameInfo] targetFrame];
    [[[self.mockWKWebView stub] andReturn:originatingURL] URL];

    [[self.mockNativeBridgeDelegate expect] close];

    [self.nativeBridge webView:self.mockWKWebView decidePolicyForNavigationAction:mockWKNavigationAction decisionHandler:^(WKNavigationActionPolicy delegatePolicy) {
       XCTAssertEqual(delegatePolicy, WKNavigationActionPolicyCancel);
    }];

    [self.mockNativeBridgeDelegate verify];
}

/**
 * Test that the multiple commands are handled properly by the native bridge.
 */
- (void)testMultiCommand {
    
    NSString *firstURLString = @"uairship://close?";
    NSString *secondURLString = @"uairship://run-basic-actions?add_tags_action=coffee&remove_tags_action=tea";
   
    NSMutableCharacterSet *characterSet = NSCharacterSet.URLQueryAllowedCharacterSet.mutableCopy;
    [characterSet removeCharactersInRange:NSMakeRange('&', 1)];
    
    NSString *finalURLString = [NSString stringWithFormat:@"uairship://multi?%@&%@", [firstURLString stringByAddingPercentEncodingWithAllowedCharacters:characterSet], [secondURLString stringByAddingPercentEncodingWithAllowedCharacters:characterSet]];
    
    
    // Airship JavaScript request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:finalURLString]];
    NSURL *originatingURL = [NSURL URLWithString:@"https://foo.urbanairship.com/whatever.html"];;

    id mockWKNavigationAction = [self mockForClass:[WKNavigationAction class]];
    [[[mockWKNavigationAction stub] andReturn:request] request];
    id mockWKFrameInfo = [self mockForClass:[WKFrameInfo class]];
    [[[mockWKNavigationAction stub] andReturn:mockWKFrameInfo] targetFrame];
    [[[self.mockWKWebView stub] andReturn:originatingURL] URL];

    [[self.mockNativeBridgeDelegate expect] close];
    
    NSDictionary *customMetadata = @{ @"cool": @"story" };

    [[[self.mockNativeBridgeExtensionDelegate stub] andReturn:customMetadata] actionsMetadataForCommand:OCMOCK_ANY webView:self.mockWKWebView];
    
    // Expect the js delegate to be called with the correct command
    [[self.mockActionHandler expect] runActionsForCommand:[OCMArg checkWithBlock:^BOOL(id obj) {
        return [((UAJavaScriptCommand *)obj).URL isEqual:[NSURL URLWithString:secondURLString]]; }]
                                                 metadata:customMetadata
                                        completionHandler:OCMOCK_ANY];

    [self.nativeBridge webView:self.mockWKWebView decidePolicyForNavigationAction:mockWKNavigationAction decisionHandler:^(WKNavigationActionPolicy delegatePolicy) {
       XCTAssertEqual(delegatePolicy, WKNavigationActionPolicyCancel);
    }];

    [self.mockActionHandler verify];
    [self.mockNativeBridgeDelegate verify];
}

/**
 * Test that the commands are not handled if the URL is not allowed.
 */
- (void)testMultiCommandWithNonAllowedURLs {
    // Airship JavaScript request
    
    NSString *firstURLString = @"https://close?";
    NSString *secondURLString = @"https://run-basic-actions?add_tags_action=coffee&remove_tags_action=tea";
    
    NSMutableCharacterSet *characterSet = NSCharacterSet.URLQueryAllowedCharacterSet.mutableCopy;
    [characterSet removeCharactersInRange:NSMakeRange('&', 1)];
    
    NSString *finalURLString = [NSString stringWithFormat:@"uairship://multi?%@&%@", [firstURLString stringByAddingPercentEncodingWithAllowedCharacters:characterSet], [secondURLString stringByAddingPercentEncodingWithAllowedCharacters:characterSet]];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:finalURLString]];
    NSURL *originatingURL = [NSURL URLWithString:@"https://foo.urbanairship.com/whatever.html"];;

    id mockWKNavigationAction = [self mockForClass:[WKNavigationAction class]];
    [[[mockWKNavigationAction stub] andReturn:request] request];
    id mockWKFrameInfo = [self mockForClass:[WKFrameInfo class]];
    [[[mockWKNavigationAction stub] andReturn:mockWKFrameInfo] targetFrame];
    [[[self.mockWKWebView stub] andReturn:originatingURL] URL];

    [[self.mockNativeBridgeDelegate reject] close];
    
    // Reject any calls to the JS Delegate
    [[self.mockActionHandler reject] runActionsForCommand:OCMOCK_ANY metadata:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [self.nativeBridge webView:self.mockWKWebView decidePolicyForNavigationAction:mockWKNavigationAction decisionHandler:^(WKNavigationActionPolicy delegatePolicy) {
       XCTAssertEqual(delegatePolicy, WKNavigationActionPolicyCancel);
    }];

    [self.mockActionHandler verify];
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
 * Test webView:didFinishNavigation: does not inject the Airship JavaScript environment when the URL is not allowed.
 */
- (void)testDidFinishNotAllowed {
    NSURL *url = [NSURL URLWithString:@"https://foo.notAllowed.com/whatever.html"];
    [[[self.mockWKWebView stub] andReturn:url] URL];
    id mockWKNavigation = [self mockForClass:[WKNavigation class]];

    // Capture the js environment string
    [[[self.mockWKWebView stub] andDo:^(NSInvocation *invocation) {
        XCTFail(@"No JS should have been injected");
    }] evaluateJavaScript:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [self.nativeBridge webView:self.mockWKWebView didFinishNavigation:mockWKNavigation];
}

/**
 * Test sending a Named User command in the Native Bridge
 */
- (void)testNamedUserCommand {
    // Mock AirshipNamedUser
    
    // Airship JavaScript request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"uairship://named_user?id=cool"]];
    NSURL *originatingURL = [NSURL URLWithString:@"https://foo.urbanairship.com/whatever.html"];
    NSString *expectedName = @"cool";
    
    id mockWKNavigationAction = [self mockForClass:[WKNavigationAction class]];
    [[[mockWKNavigationAction stub] andReturn:request] request];
    id mockWKFrameInfo = [self mockForClass:[WKFrameInfo class]];
    [[[mockWKNavigationAction stub] andReturn:mockWKFrameInfo] targetFrame];
    [[[self.mockWKWebView stub] andReturn:originatingURL] URL];

    [[self.mockContact expect] identify:expectedName];

    [self.nativeBridge webView:self.mockWKWebView decidePolicyForNavigationAction:mockWKNavigationAction decisionHandler:^(WKNavigationActionPolicy delegatePolicy) {
       XCTAssertEqual(delegatePolicy, WKNavigationActionPolicyCancel);
    }];

    [self.mockContact verify];
}

/**
 * Test sending an encoded Named User command in the Native Bridge
 */
- (void)testEncodedNamedUserCommand {
    // Mock AirshipNamedUser
    // Airship JavaScript request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"uairship://named_user?id=my%2Fname%26%20user"]];
    NSURL *originatingURL = [NSURL URLWithString:@"https://foo.urbanairship.com/whatever.html"];
    NSString *expectedName = @"my/name& user";
    
    id mockWKNavigationAction = [self mockForClass:[WKNavigationAction class]];
    [[[mockWKNavigationAction stub] andReturn:request] request];
    id mockWKFrameInfo = [self mockForClass:[WKFrameInfo class]];
    [[[mockWKNavigationAction stub] andReturn:mockWKFrameInfo] targetFrame];
    [[[self.mockWKWebView stub] andReturn:originatingURL] URL];

    [[self.mockContact expect] identify:expectedName];
    
    [self.nativeBridge webView:self.mockWKWebView decidePolicyForNavigationAction:mockWKNavigationAction decisionHandler:^(WKNavigationActionPolicy delegatePolicy) {
       XCTAssertEqual(delegatePolicy, WKNavigationActionPolicyCancel);
    }];

    [self.mockContact verify];
}

/**
 * Test sending a null Named User to the Native Bridge
 */
- (void)testNullNamedUserCommand {
        // Airship JavaScript request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"uairship://named_user?id="]];
    NSURL *originatingURL = [NSURL URLWithString:@"https://foo.urbanairship.com/whatever.html"];
    
    id mockWKNavigationAction = [self mockForClass:[WKNavigationAction class]];
    [[[mockWKNavigationAction stub] andReturn:request] request];
    id mockWKFrameInfo = [self mockForClass:[WKFrameInfo class]];
    [[[mockWKNavigationAction stub] andReturn:mockWKFrameInfo] targetFrame];
    [[[self.mockWKWebView stub] andReturn:originatingURL] URL];

    [[self.mockContact expect] reset];

    [self.nativeBridge webView:self.mockWKWebView decidePolicyForNavigationAction:mockWKNavigationAction decisionHandler:^(WKNavigationActionPolicy delegatePolicy) {
       XCTAssertEqual(delegatePolicy, WKNavigationActionPolicyCancel);
    }];

    [self.mockContact verify];
}

@end
