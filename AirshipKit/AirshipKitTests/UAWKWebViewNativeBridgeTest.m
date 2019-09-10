/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import <JavaScriptCore/JavaScriptCore.h>

#import "UAWKWebViewNativeBridge.h"
#import "UAWebView+Internal.h"
#import "UAirship+Internal.h"
#import "UARuntimeConfig.h"
#import "UAUser+Internal.h"
#import "UAUserData+Internal.h"
#import "UAInboxMessage.h"
#import "UAUtils+Internal.h"
#import "UAInbox.h"
#import "UAInboxMessageList.h"
#import "UAActionJSDelegate.h"
#import "UAWebViewCallData.h"
#import "UAChannel.h"
#import "UANamedUser.h"

@interface UAWKWebViewNativeBridgeTest : UABaseTest

@property(nonatomic, strong) UAWKWebViewNativeBridge *nativeBridge;
@property(nonatomic, strong) id mockWKWebView;
@property(nonatomic, strong) id mockUAWebView;
@property(nonatomic, strong) id mockWKNavigation;
@property(nonatomic, strong) id mockForwardDelegate;
@property(nonatomic, strong) id mockWKNavigationAction;
@property(nonatomic, strong) id mockContentWindow;

@property (strong, nonatomic) id mockUIDevice;
@property (strong, nonatomic) id mockUAUser;
@property (strong, nonatomic) id mockAirship;
@property (strong, nonatomic) id mockJSActionDelegate;
@property (nonatomic, strong) id mockMessageList;
@property (nonatomic, strong) id mockInbox;
@property (nonatomic, strong) id mockChannel;
@property (nonatomic, strong) id mockNamedUser;
@property (nonatomic, strong) id mockConfig;

@property (nonatomic, strong) JSContext *jsc;

@end


@implementation UAWKWebViewNativeBridgeTest

- (void)setUp {
    [super setUp];
    self.nativeBridge = [[UAWKWebViewNativeBridge alloc] init];
    self.mockForwardDelegate = [self mockForProtocol:@protocol(UAWKWebViewDelegate)];
    self.nativeBridge.forwardDelegate = self.mockForwardDelegate;


    // Mock UAChannel
    self.mockChannel = [self mockForClass:[UAChannel class]];

    // Mock UANamedUser
    self.mockNamedUser = [self mockForClass:[UANamedUser class]];

    // Mock WKWebView
    self.mockWKWebView = [self mockForClass:[WKWebView class]];
    
    // Mock UAWebView
    self.mockUAWebView = [self mockForClass:[UAWebView class]];
    
    // Mock WKNavigation
    self.mockWKNavigation = [self mockForClass:[WKNavigation class]];
    
    // Mock WKNavigationAction
    self.mockWKNavigationAction = [self mockForClass:[WKNavigationAction class]];

    // Mock UAUser
    self.mockUAUser = [self mockForClass:[UAUser class]];

    // Mock UARuntimeConfig
    self.mockConfig = [self mockForClass:[UARuntimeConfig class]];
    
    // Mock UIDevice
    self.mockUIDevice = [self mockForClass:[UIDevice class]];
    [[[self.mockUIDevice stub] andReturn:self.mockUIDevice] currentDevice];

    // Mock the inbox and message list
    self.mockInbox = [self mockForClass:[UAInbox class]];
    self.mockMessageList = [self mockForClass:[UAInboxMessageList class]];
    [[[self.mockInbox stub] andReturn:self.mockMessageList] messageList];

    // Mock Airship
    self.mockAirship = [self mockForClass:[UAirship class]];
    [UAirship setSharedAirship:self.mockAirship];
    [[[self.mockAirship stub] andReturn:self.mockUAUser] inboxUser];
    [[[self.mockAirship stub] andReturn:self.mockInbox] inbox];
    [[[self.mockAirship stub] andReturn:self.mockChannel] channel];
    [[[self.mockAirship stub] andReturn:self.mockNamedUser] namedUser];
    [[[self.mockAirship stub] andReturn:self.mockConfig] config];

    // Mock JS Action delegate
    self.mockJSActionDelegate = [self mockForClass:[UAActionJSDelegate class]];
    [[[self.mockAirship stub] andReturn:self.mockJSActionDelegate] actionJSDelegate];

    // Set an actual whitelist
    UAWhitelist *whitelist = [UAWhitelist whitelistWithConfig:self.config];
    [[[self.mockAirship stub] andReturn:whitelist] whitelist];

    // Set up a Javascript environment
    self.jsc = [[JSContext alloc] initWithVirtualMachine:[[JSVirtualMachine alloc] init]];
    [self.jsc evaluateScript:@"window = {}"];
}

- (void)tearDown {
    [self.mockAirship stopMocking];
    [self.mockWKWebView stopMocking];
    [self.mockUAWebView stopMocking];
    [self.mockUIDevice stopMocking];
    [self.mockUAUser stopMocking];
    [self.mockConfig stopMocking];
    [self.mockForwardDelegate stopMocking];
    [self.mockContentWindow stopMocking];

    [self.mockMessageList stopMocking];
    [self.mockInbox stopMocking];
    [self.mockChannel stopMocking];
    [self.mockNamedUser stopMocking];

    [super tearDown];
}

/**
 * Test webView:didCommitNavigation: forwards its message to the forwardDelegate.
 */
- (void)testDidCommitNavigationForwardDelegate {
    [[self.mockForwardDelegate expect] webView:self.mockWKWebView didCommitNavigation:self.mockWKNavigation];
    [self.nativeBridge webView:self.mockWKWebView didCommitNavigation:self.mockWKNavigation];
    [self.mockForwardDelegate verify];
}

/**
 * Test webView:didFailNavigation:withError: forwards its message to the forwardDelegate.
 */
- (void)testDidFailNavigationWithErrorForwardDelegate {
    NSError *err = [NSError errorWithDomain:@"wat" code:0 userInfo:nil];
    [[self.mockForwardDelegate expect] webView:self.mockWKWebView didFailNavigation:self.mockWKNavigation withError:err];
    [self.nativeBridge webView:self.mockWKWebView didFailNavigation:self.mockWKNavigation withError:err];
    [self.mockForwardDelegate verify];
}

/**
 * Test webView:decidePolicyForNavigationAction:decisionHandler: forwards its message to the forwardDelegate.
 */
- (void)testDecidePolicyForNavigationActionDecisionHandlerForwardDelegate {
    // Stub the forward delegate to return the response
    [[[self.mockForwardDelegate expect] andDo:^(NSInvocation *invocation) {
        void (^decisionHandler)(WKNavigationActionPolicy policy) = nil;
        [invocation getArgument:&decisionHandler atIndex:4];
        decisionHandler(WKNavigationActionPolicyCancel);
    }] webView:OCMOCK_ANY decidePolicyForNavigationAction:OCMOCK_ANY decisionHandler:OCMOCK_ANY];

    [self.nativeBridge webView:self.mockWKWebView decidePolicyForNavigationAction:self.mockWKNavigationAction decisionHandler:^(WKNavigationActionPolicy delegatePolicy) {
        XCTAssertEqual(delegatePolicy,WKNavigationActionPolicyCancel);
    }];

    [self.mockForwardDelegate verify];

    [[[self.mockForwardDelegate expect] andDo:^(NSInvocation *invocation) {
        void (^decisionHandler)(WKNavigationActionPolicy policy) = nil;
        [invocation getArgument:&decisionHandler atIndex:4];
        decisionHandler(WKNavigationActionPolicyAllow);
    }] webView:OCMOCK_ANY decidePolicyForNavigationAction:OCMOCK_ANY decisionHandler:OCMOCK_ANY];
    
    [self.nativeBridge webView:self.mockWKWebView decidePolicyForNavigationAction:self.mockWKNavigationAction decisionHandler:^(WKNavigationActionPolicy delegatePolicy) {
        XCTAssertEqual(delegatePolicy,WKNavigationActionPolicyAllow);
    }];
    
    [self.mockForwardDelegate verify];
}

/**
 * Test webView:decidePolicyForNavigationAction:decisionHandler: forwards uairship:// schemes
 * to the Airship Action JS delegate with the associated inbox message.
 */
- (void)testShouldStartLoadRunsActions {
    // Action request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"uairship://run-basic-actions?test_action=hi"]];
    NSURL *originatingURL = [NSURL URLWithString:@"https://foo.urbanairship.com/whatever.html"];;
    [[[self.mockWKNavigationAction stub] andReturn:request] request];

    // Create an inbox message
    NSDate *messageSent = [NSDate date];
    id message = [self mockForClass:[UAInboxMessage class]];
    [[[message stub] andReturn:@"messageID"] messageID];
    [[[message stub] andReturn:@"messageTitle"] title];
    [[[message stub] andReturn:messageSent] messageSent];
    [[[message stub] andReturnValue:@(YES)] unread];

    // Associate the URL with the mock message
    [[[self.mockMessageList stub] andReturn:message] messageForBodyURL:originatingURL];

    [[[self.mockWKWebView stub] andReturn:originatingURL] URL];

    // Expect the js delegate to be called with the correct call data
    [[self.mockJSActionDelegate expect] callWithData:[OCMArg checkWithBlock:^BOOL(id obj) {
        UAWebViewCallData *data = obj;

        if (![data.url isEqual:request.URL]) {
            return NO;
        }

        if (data.message != message) {
            return NO;
        }

        return YES;

    }] withCompletionHandler:OCMOCK_ANY];

    [self.nativeBridge webView:self.mockWKWebView decidePolicyForNavigationAction:self.mockWKNavigationAction decisionHandler:^(WKNavigationActionPolicy delegatePolicy) {
    }];

    [self.mockJSActionDelegate verify];
}

/**
 * Test webView:shouldStartLoadWithRequest:navigationType: does not forward uairship:// schemes
 * to the Airship Action JS delegate if the URL is not whitelisted.
 */
- (void)testShouldStartLoadRejectsActionRunsNotWhitelisted {
    // Action request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"uairship://run-basic-actions?test_action=hi"]];
    NSURL *originatingURL = [NSURL URLWithString:@"https://foo.notwhitelisted.com/whatever.html"];;

    [[[self.mockWKWebView stub] andReturn:originatingURL] URL];

    [[[self.mockWKNavigationAction stub] andReturn:request] request];

    // Reject any calls to the JS Delegate
    [[self.mockJSActionDelegate reject] callWithData:OCMOCK_ANY withCompletionHandler:OCMOCK_ANY];

    [self.nativeBridge webView:self.mockWKWebView decidePolicyForNavigationAction:self.mockWKNavigationAction decisionHandler:^(WKNavigationActionPolicy delegatePolicy) {
    }];

    [self.mockJSActionDelegate verify];
}

/**
 * Test webView:didFinishNavigation: forwards its message to the forwardDelegate.
 */
- (void)testDidFinishLoadForwardDelegate {
    [[self.mockForwardDelegate expect] webView:self.mockWKWebView didFinishNavigation:self.mockWKNavigation];
    [self.nativeBridge webView:self.mockWKWebView didFinishNavigation:self.mockWKNavigation];
    [self.mockForwardDelegate verify];
}

/**
 * Test closeWindowAnimated: forwards its message to the richContentWindow.
 */
- (void)testcloseWindowAnimated {
    [[self.mockContentWindow expect] closeWindowAnimated:YES];
    [self.nativeBridge closeWindowAnimated:YES];
    [self.mockForwardDelegate verify];
}

/**
 * Test webView:didFinishNavigation: injects the Airship Javascript interface.
 */
- (void)testDidFinishPopulateJavascriptEnvironmentWithWKWebView {
    [self commonTestDidFinishPopulateJavascriptEnvironmentWithUAWebView:NO];
}

/**
 * Test webView:didFinishNavigation: injects the Airship Javascript interface.
 */
- (void)testDidFinishPopulateJavascriptEnvironmentWithUAWebView {
    [self commonTestDidFinishPopulateJavascriptEnvironmentWithUAWebView:YES];
}

- (void)commonTestDidFinishPopulateJavascriptEnvironmentWithUAWebView:(BOOL)testUAWebView {

    UAUserData *userData = [UAUserData dataWithUsername:@"username" password:@"password"];

    [[[self.mockUAUser stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        void (^completionHandler)(UAUserData * _Nullable) = (__bridge void (^)(UAUserData * _Nullable)) arg;
        completionHandler(userData);
    }] getUserData:OCMOCK_ANY dispatcher:OCMOCK_ANY];

    [[[self.mockUIDevice stub] andReturn:@"device model"] model];
    [[[self.mockChannel stub] andReturn:@"channel ID"] identifier];
    [[[self.mockNamedUser stub] andReturn:@"named user"] identifier];
    [[[self.mockConfig stub] andReturn:@"application key"] appKey];
    
    __block NSString *js;
    __block NSError *error = nil;
    
    id mockWebView = (testUAWebView)? self.mockUAWebView : self.mockWKWebView;

    // Capture the js environment string
    [[[mockWebView stub] andDo:^(NSInvocation *invocation) {
        [invocation getArgument:&js atIndex:2];
        void (^completionHandler)(id, NSError *error) = nil;
        [invocation getArgument:&completionHandler atIndex:3];
        if (completionHandler) {
            completionHandler(js,error);
        }
    }] evaluateJavaScript:[OCMArg any] completionHandler:[OCMArg any]];
    
    // Any https://*.urbanairship.com/* urls are white listed
    NSURL *url = [NSURL URLWithString:@"https://foo.urbanairship.com/whatever.html"];
    [[[mockWebView stub] andReturn:url] URL];
    
    // Notify the web view is finished loading the main frame
    [self.nativeBridge webView:mockWebView didFinishNavigation:self.mockWKNavigation];
    
    XCTAssertNotNil(js, "Javascript environment was not populated");
    if (js) {
        [self.jsc evaluateScript:js];
    }

    // Verify device model
    XCTAssertEqualObjects(@"device model", [self.jsc evaluateScript:@"UAirship.getDeviceModel()"].toString);
    
    // Verify user ID
    XCTAssertEqualObjects(@"username", [self.jsc evaluateScript:@"UAirship.getUserId()"].toString);
    
    // Verify channel ID
    XCTAssertEqualObjects(@"channel ID", [self.jsc evaluateScript:@"UAirship.getChannelId()"].toString);
    
    // Verify named user
    XCTAssertEqualObjects(@"named user", [self.jsc evaluateScript:@"UAirship.getNamedUser()"].toString);
    
    // Verify app key
    XCTAssertEqualObjects(@"application key", [self.jsc evaluateScript:@"UAirship.getAppKey()"].toString);
    
    // Verify message ID is null
    XCTAssertTrue([self.jsc evaluateScript:@"UAirship.getMessageId()"].isNull);
    
    // Verify message title is null
    XCTAssertTrue([self.jsc evaluateScript:@"UAirship.getMessageTitle()"].isNull);
    
    // Verify message send date is null
    XCTAssertTrue([self.jsc evaluateScript:@"UAirship.getMessageSentDate()"].isNull);
    
    // Verify message send date ms is -1
    XCTAssertEqualObjects(@-1, [self.jsc evaluateScript:@"UAirship.getMessageSentDateMS()"].toNumber);
    
    // Verify native bridge methods are not undefined
    XCTAssertFalse([self.jsc evaluateScript:@"UAirship.runAction"].isUndefined);
    XCTAssertFalse([self.jsc evaluateScript:@"UAirship.finishAction"].isUndefined);
}

/**
 * Test webView:didFinishNavigation: injects the Airship Javascript interface with the
 * inbox message information if the web view's main document url points to
 * a message's body URL.
 */
- (void)testDidFinishPopulateJavascriptEnvironmentWithInboxMessage {

    NSDate *messageSent = [NSDate date];
    id message = [self mockForClass:[UAInboxMessage class]];
    [[[message stub] andReturn:@"messageID"] messageID];
    [[[message stub] andReturn:@"messageTitle"] title];
    [[[message stub] andReturn:messageSent] messageSent];
    [[[message stub] andReturnValue:@(YES)] unread];

    __block NSString *js;
    __block NSError *error = nil;

    // Capture the js environment string
    [[[self.mockWKWebView stub] andDo:^(NSInvocation *invocation) {
        NSLog(@"js = %@",js);
        [invocation getArgument:&js atIndex:2];
        NSLog(@"js = %@",js);
        void (^completionHandler)(id, NSError *error) = nil;
        [invocation getArgument:&completionHandler atIndex:3];
        if (completionHandler) {
            completionHandler(js,error);
        }
    }] evaluateJavaScript:[OCMArg any] completionHandler:[OCMArg any]];

    NSURL *url = [NSURL URLWithString:@"https://foo.urbanairship.com/whatever.html"];

    // Associate the URL with the mock message
    [[[self.mockMessageList stub] andReturn:message] messageForBodyURL:url];

    [[[self.mockWKWebView stub] andReturn:url] URL];

    UAUserData *userData = [UAUserData dataWithUsername:@"username" password:@"password"];

    XCTestExpectation *userDataRetrieved = [self expectationWithDescription:@"user data retrieved"];

    [[[self.mockUAUser stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        void (^completionHandler)(UAUserData * _Nullable) = (__bridge void (^)(UAUserData * _Nullable)) arg;
        completionHandler(userData);
        [userDataRetrieved fulfill];
    }] getUserData:OCMOCK_ANY dispatcher:OCMOCK_ANY];


    [self.nativeBridge webView:self.mockWKWebView didFinishNavigation:self.mockWKNavigation];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    XCTAssertNotNil(js, "Javascript environment was not populated");

    if (js) {
        [self.jsc evaluateScript:js];
    }

    // Verify message ID
    XCTAssertEqualObjects(@"messageID", [self.jsc evaluateScript:@"UAirship.getMessageId()"].toString);

    // Verify message title
    XCTAssertEqualObjects(@"messageTitle", [self.jsc evaluateScript:@"UAirship.getMessageTitle()"].toString);

    // Verify message send date
    XCTAssertEqualObjects([[UAUtils ISODateFormatterUTC] stringFromDate:messageSent], [self.jsc evaluateScript:@"UAirship.getMessageSentDate()"].toString);

    // Verify message send date ms
    double milliseconds = [messageSent timeIntervalSince1970] * 1000;
    XCTAssertEqualWithAccuracy(milliseconds, [self.jsc evaluateScript:@"UAirship.getMessageSentDateMS()"].toDouble, 0.001);

    [message stopMocking];
}

/**
 * Test loading the JS environemnt when a message contains a title with invalid JSON
 * characters is properly escaped.
 */
- (void)testLoadJSEnvironmentWithInvalidJSONCharactersMessageTitle {
    id message = [self mockForClass:[UAInboxMessage class]];

    /*
     * From RFC 4627, "All Unicode characters may be placed within the
     * quotation marks except for the characters that must be escaped:
     * quotation mark, reverse solidus, and the control characters
     * (U+0000 through U+001F)."
     */
    [[[message stub] andReturn:@"\"\t\b\r\n\f/title"] title];

    __block NSString *js;
    __block NSError *error = nil;

    // Capture the js environment string
    [[[self.mockWKWebView stub] andDo:^(NSInvocation *invocation) {
        NSLog(@"js = %@",js);
        [invocation getArgument:&js atIndex:2];
        NSLog(@"js = %@",js);
        void (^completionHandler)(id, NSError *error) = nil;
        [invocation getArgument:&completionHandler atIndex:3];
        if (completionHandler) {
            completionHandler(js,error);
        }
    }] evaluateJavaScript:[OCMArg any] completionHandler:[OCMArg any]];

    NSURL *url = [NSURL URLWithString:@"https://foo.urbanairship.com/whatever.html"];

    // Associate the URL with the mock message
    [[[self.mockMessageList stub] andReturn:message] messageForBodyURL:url];

    [[[self.mockWKWebView stub] andReturn:url] URL];

    UAUserData *userData = [UAUserData dataWithUsername:@"username" password:@"password"];

    XCTestExpectation *userDataRetrieved = [self expectationWithDescription:@"user data retrieved"];

    [[[self.mockUAUser stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        void (^completionHandler)(UAUserData * _Nullable) = (__bridge void (^)(UAUserData * _Nullable)) arg;
        completionHandler(userData);
        [userDataRetrieved fulfill];
    }] getUserData:OCMOCK_ANY dispatcher:OCMOCK_ANY];


    [self.nativeBridge webView:self.mockWKWebView didFinishNavigation:self.mockWKNavigation];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];


    XCTAssertNotNil(js, "Javascript environment was not populated");

    if (js) {
        [self.jsc evaluateScript:js];
    }

    // Verify message title
    XCTAssertEqualObjects(@"\"\t\b\r\n\f/title", [self.jsc evaluateScript:@"UAirship.getMessageTitle()"].toString);

    [message stopMocking];
}


/**
 * Test that webView:didFinishNavigation: does not load the JS environment when the URL is not whitelisted.
 */
- (void)testDidFinishNotWhitelisted {
    NSURL *url = [NSURL URLWithString:@"https://foo.notwhitelisted.com/whatever.html"];
    [[[self.mockWKWebView stub] andReturn:url] URL];

    // Capture the js environment string
    [[[self.mockWKWebView stub] andDo:^(NSInvocation *invocation) {
        XCTFail(@"No JS should have been injected");
    }] evaluateJavaScript:[OCMArg any] completionHandler:[OCMArg any]];

    [self.nativeBridge webView:self.mockWKWebView didFinishNavigation:self.mockWKNavigation];
}

@end
