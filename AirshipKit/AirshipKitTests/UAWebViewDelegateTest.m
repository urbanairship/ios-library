/* Copyright 2017 Urban Airship and Contributors */

#import <UIKit/UIKit.h>
#import "UABaseTest.h"
#import <OCMock/OCMock.h>
#import <JavaScriptCore/JavaScriptCore.h>

#import "UAWebViewDelegate.h"
#import "UAirship+Internal.h"
#import "UAConfig.h"
#import "UAUser.h"
#import "UAInboxMessage.h"
#import "UAUtils.h"
#import "UAInbox.h"
#import "UAInboxMessageList.h"
#import "UAActionJSDelegate.h"
#import "UAWebViewCallData.h"
#import "UAPush.h"
#import "UANamedUser.h"

@interface UAWebViewDelegateTest : UABaseTest

@property(nonatomic, strong) UAWebViewDelegate *delegate;
@property(nonatomic, strong) id mockWebView;
@property(nonatomic, strong) id mockForwardDelegate;
@property(nonatomic, strong) id mockContentWindow;

@property (strong, nonatomic) id mockUIDevice;
@property (strong, nonatomic) id mockUAUser;
@property (strong, nonatomic) id mockAirship;
@property (strong, nonatomic) id mockJSActionDelegate;
@property (nonatomic, strong) id mockMessageList;
@property (nonatomic, strong) id mockInbox;
@property (nonatomic, strong) id mockPush;
@property (nonatomic, strong) id mockNamedUser;
@property (nonatomic, strong) id mockConfig;

@property (nonatomic, strong) JSContext *jsc;

@end


@implementation UAWebViewDelegateTest

- (void)setUp {
    [super setUp];
    self.delegate = [[UAWebViewDelegate alloc] init];
    self.mockForwardDelegate = [self mockForProtocol:@protocol(UAUIWebViewDelegate)];
    self.delegate.forwardDelegate = self.mockForwardDelegate;

    self.mockContentWindow = [self mockForProtocol:@protocol(UARichContentWindow)];
    self.delegate.richContentWindow = self.mockContentWindow;

    // Mock UAPush
    self.mockPush = [self mockForClass:[UAPush class]];

    // Mock UANamedUser
    self.mockNamedUser = [self mockForClass:[UANamedUser class]];

    // Mock web view
    self.mockWebView = [self mockForClass:[UIWebView class]];

    // Mock UAUser
    self.mockUAUser = [self mockForClass:[UAUser class]];

    // Mock UAConfig
    self.mockConfig = [self mockForClass:[UAConfig class]];
    
    // Mock UIDevice
    self.mockUIDevice = [self mockForClass:[UIDevice class]];
    [[[self.mockUIDevice stub] andReturn:self.mockUIDevice] currentDevice];

    // Mock the inbox and message list
    self.mockInbox = [self mockForClass:[UAInbox class]];
    self.mockMessageList = [self mockForClass:[UAInboxMessageList class]];
    [[[self.mockInbox stub] andReturn:self.mockMessageList] messageList];

    // Mock Airship
    self.mockAirship = [self mockForClass:[UAirship class]];
    [[[self.mockAirship stub] andReturn:self.mockAirship] shared];
    [[[self.mockAirship stub] andReturn:self.mockUAUser] inboxUser];
    [[[self.mockAirship stub] andReturn:self.mockInbox] inbox];
    [[[self.mockAirship stub] andReturn:self.mockPush] push];
    [[[self.mockAirship stub] andReturn:self.mockNamedUser] namedUser];
    [[[self.mockAirship stub] andReturn:self.mockConfig] config];

    // Mock JS Action delegate
    self.mockJSActionDelegate = [self mockForClass:[UAActionJSDelegate class]];
    [[[self.mockAirship stub] andReturn:self.mockJSActionDelegate] actionJSDelegate];

    // Set an actual whitelist
    UAWhitelist *whitelist = [UAWhitelist whitelistWithConfig:[UAConfig defaultConfig]];
    [[[self.mockAirship stub] andReturn:whitelist] whitelist];

    // Set up a Javascript environment
    self.jsc = [[JSContext alloc] initWithVirtualMachine:[[JSVirtualMachine alloc] init]];
    [self.jsc evaluateScript:@"window = {}"];
}

- (void)tearDown {
    [self.mockAirship stopMocking];
    [self.mockWebView stopMocking];
    [self.mockUIDevice stopMocking];
    [self.mockUAUser stopMocking];
    [self.mockConfig stopMocking];
    [self.mockForwardDelegate stopMocking];
    [self.mockContentWindow stopMocking];

    [self.mockMessageList stopMocking];
    [self.mockInbox stopMocking];
    [self.mockPush stopMocking];
    [self.mockNamedUser stopMocking];

    [super tearDown];
}

/**
 * Test webViewDidStartLoad: forwards its message to the forwardDelegate.
 */
- (void)testDidStartLoadForwardDelegate {
    [[self.mockForwardDelegate expect] webViewDidStartLoad:self.mockWebView];
    [self.delegate webViewDidStartLoad:self.mockWebView];
    [self.mockForwardDelegate verify];
}

/**
 * Test webView:didFailLoadWithError: forwards its message to the forwardDelegate.
 */
- (void)testDidFailLoadForwardDelegate {
    NSError *err = [NSError errorWithDomain:@"wat" code:0 userInfo:nil];
    [[self.mockForwardDelegate expect] webView:self.mockWebView didFailLoadWithError:err];
    [self.delegate webView:self.mockWebView didFailLoadWithError:err];
    [self.mockForwardDelegate verify];
}

/**
 * Test webView:shouldStartLoadWithRequest:navigationType: forwards its message to the forwardDelegate.
 */
- (void)testShouldStartLoadForwardDelegate {
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://urbanairship.com"]];
    [[self.mockForwardDelegate expect] webView:self.mockWebView shouldStartLoadWithRequest:request navigationType:UIWebViewNavigationTypeOther];
    [self.delegate webView:self.mockWebView shouldStartLoadWithRequest:request navigationType:UIWebViewNavigationTypeOther];
    [self.mockForwardDelegate verify];
}


/**
 * Test webView:shouldStartLoadWithRequest:navigationType: forwards uairship:// schemes
 * to the Urban Airship Action JS delegate with the associated inbox message.
 */
- (void)testShouldStartLoadRunsActions {
    // Action request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"uairship://run-basic-actions?test_action=hi"]];
    request.mainDocumentURL = [NSURL URLWithString:@"https://foo.urbanairship.com/whatever.html"];;
    [[[self.mockWebView stub] andReturn:request] request];

    // Create an inbox message
    NSDate *messageSent = [NSDate date];
    id message = [self mockForClass:[UAInboxMessage class]];
    [[[message stub] andReturn:@"messageID"] messageID];
    [[[message stub] andReturn:@"messageTitle"] title];
    [[[message stub] andReturn:messageSent] messageSent];
    [[[message stub] andReturnValue:@(YES)] unread];

    // Associate the URL with the mock message
    [[[self.mockMessageList stub] andReturn:message] messageForBodyURL:request.mainDocumentURL];

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

    [self.delegate webView:self.mockWebView shouldStartLoadWithRequest:request navigationType:UIWebViewNavigationTypeOther];

    [self.mockJSActionDelegate verify];
}

/**
 * Test webView:shouldStartLoadWithRequest:navigationType: does not forward uairship:// schemes
 * to the Urban Airship Action JS delegate if the URL is not whitelisted.
 */
- (void)testShouldStartLoadRejectsActionRunsNotWhitelisted {
    // Action request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"uairship://run-basic-actions?test_action=hi"]];
    request.mainDocumentURL = [NSURL URLWithString:@"https://foo.notwhitelisted.com/whatever.html"];;
    [[[self.mockWebView stub] andReturn:request] request];

    // Reject any calls to the JS Delegate
    [[self.mockJSActionDelegate reject] callWithData:OCMOCK_ANY withCompletionHandler:OCMOCK_ANY];

    [self.delegate webView:self.mockWebView shouldStartLoadWithRequest:request navigationType:UIWebViewNavigationTypeOther];

    [self.mockJSActionDelegate verify];
}

/**
 * Test webViewDidFinishLoad: forwards its message to the forwardDelegate.
 */
- (void)testDidFinishLoadForwardDelegate {
    [[self.mockForwardDelegate expect] webViewDidFinishLoad:self.mockWebView];
    [self.delegate webViewDidFinishLoad:self.mockWebView];
    [self.mockForwardDelegate verify];
}

/**
 * Test closeWebView:animated: forwards its message to the richContentWindow.
 */
- (void)testCloseWebView {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    [[self.mockContentWindow expect] closeWebView:self.mockWebView animated:YES];
    [self.delegate closeWebView:self.mockWebView animated:YES];
#pragma GCC diagnostic pop
}

/**
 * Test closeWindowAnimated: forwards its message to the richContentWindow.
 */
- (void)testCloseWindowAnimated {
    [[self.mockForwardDelegate expect] closeWindowAnimated:YES];
    [self.delegate closeWindowAnimated:YES];
}

/**
 * Test webViewDidFinishLoad: injects the UA Javascript interface.
 */
- (void)testDidFinishPopulateJavascriptEnvironment {
    [[[self.mockUAUser stub] andReturn:@"user name"] username];
    [[[self.mockUIDevice stub] andReturn:@"device model"] model];
    [[[self.mockPush stub] andReturn:@"channel ID"] channelID];
    [[[self.mockNamedUser stub] andReturn:@"named user"] identifier];
    [[[self.mockConfig stub] andReturn:@"application key"] appKey];
    
    __block NSString *js;

    // Capture the js environment string
    [[[self.mockWebView stub] andDo:^(NSInvocation *invocation) {
        [invocation getArgument:&js atIndex:2];
        [invocation setReturnValue:&js];
    }] stringByEvaluatingJavaScriptFromString:[OCMArg any]];

    // Any https://*.urbanairship.com/* urls are white listed
    NSURL *url = [NSURL URLWithString:@"https://foo.urbanairship.com/whatever.html"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.mainDocumentURL = url;
    [[[self.mockWebView stub] andReturn:request] request];

    // Notifiy the web view is finished loading the main frame
    [self.delegate webViewDidFinishLoad:self.mockWebView];

    XCTAssertNotNil(js, "Javascript environment was not populated");

    [self.jsc evaluateScript:js];

    // Verify device model
    XCTAssertEqualObjects(@"device model", [self.jsc evaluateScript:@"UAirship.getDeviceModel()"].toString);

    // Verify user ID
    XCTAssertEqualObjects(@"user name", [self.jsc evaluateScript:@"UAirship.getUserId()"].toString);

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
 * Test webViewDidFinishLoad: injects the UA Javascript interface with the
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

    // Capture the js environment string
    [[[self.mockWebView stub] andDo:^(NSInvocation *invocation) {
        [invocation getArgument:&js atIndex:2];
        [invocation setReturnValue:&js];
    }] stringByEvaluatingJavaScriptFromString:[OCMArg any]];

    NSURL *url = [NSURL URLWithString:@"https://foo.urbanairship.com/whatever.html"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.mainDocumentURL = url;


    // Associate the URL with the mock message
    [[[self.mockMessageList stub] andReturn:message] messageForBodyURL:url];

    [[[self.mockWebView stub] andReturn:request] request];

    [self.delegate webViewDidFinishLoad:self.mockWebView];

    XCTAssertNotNil(js, "Javascript environment was not populated");

    [self.jsc evaluateScript:js];

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

    // Capture the js environment string
    [[[self.mockWebView stub] andDo:^(NSInvocation *invocation) {
        [invocation getArgument:&js atIndex:2];
        [invocation setReturnValue:&js];
    }] stringByEvaluatingJavaScriptFromString:[OCMArg any]];

    NSURL *url = [NSURL URLWithString:@"https://foo.urbanairship.com/whatever.html"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.mainDocumentURL = url;


    // Associate the URL with the mock message
    [[[self.mockMessageList stub] andReturn:message] messageForBodyURL:url];

    [[[self.mockWebView stub] andReturn:request] request];

    [self.delegate webViewDidFinishLoad:self.mockWebView];

    XCTAssertNotNil(js, "Javascript environment was not populated");

    [self.jsc evaluateScript:js];

    // Verify message title
    XCTAssertEqualObjects(@"\"\t\b\r\n\f/title", [self.jsc evaluateScript:@"UAirship.getMessageTitle()"].toString);

    [message stopMocking];
}


/**
 * Test that webViewDidFinishLoad: does not load the JS environment when the URL is not whitelisted.
 */
- (void)testDidFinishNotWhitelitsed {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://foo.notwhitelisted.com/whatever.html"]];
    request.mainDocumentURL = request.URL;

    [[[self.mockWebView stub] andReturn:request] request];

    // Capture the js environment string
    [[[self.mockWebView stub] andDo:^(NSInvocation *invocation) {
        XCTFail(@"No JS should have been injected");
    }] stringByEvaluatingJavaScriptFromString:[OCMArg any]];

    [self.delegate webViewDidFinishLoad:self.mockWebView];
}

/**
 * Test that webViewDidFinishLoad: only popluates the JS interface once even if called
 * multiple time.
 */
- (void)testDidFinishCalledMultipleTimes {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://foo.urbanairship.com/whatever.html"]];
    request.mainDocumentURL = request.URL;

    [[[self.mockWebView stub] andReturn:request] request];

    // Expect the interface to be injected.
    [[self.mockWebView expect] stringByEvaluatingJavaScriptFromString:[OCMArg any]];

    [self.delegate webViewDidFinishLoad:self.mockWebView];
    [self.mockWebView verify];

    // Verify it does not inject any JS interface a second time
    [[self.mockWebView reject] stringByEvaluatingJavaScriptFromString:[OCMArg any]];
    [self.delegate webViewDidFinishLoad:self.mockWebView];
    [self.mockWebView verify];
}

@end
