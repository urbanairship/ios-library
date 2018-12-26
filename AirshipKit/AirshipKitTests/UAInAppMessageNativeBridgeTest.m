
#import "UABaseTest.h"
#import "UAInAppMessageNativeBridge+Internal.h"
#import "UAJavaScriptDelegate.h"
#import "UAWebView+Internal.h"
#import "UAirship+Internal.h"
#import "UAActionJSDelegate.h"

@interface UAInAppMessageNativeBridgeTest : UABaseTest
@property (nonatomic, strong) UAInAppMessageNativeBridge *bridge;
@property (nonatomic, strong) id mockMessageJSDelegate;
@property (nonatomic, strong) id mockActionJSDelegate;
@property (nonatomic, strong) id mockAirship;
@end

@implementation UAInAppMessageNativeBridgeTest

- (void)setUp {
    self.bridge = [[UAInAppMessageNativeBridge alloc] init];
    self.mockMessageJSDelegate = [self mockForProtocol:@protocol(UAJavaScriptDelegate)];
    self.bridge.messageJSDelegate = self.mockMessageJSDelegate;

    // Mock Airship
    self.mockAirship = [self mockForClass:[UAirship class]];
    [UAirship setSharedAirship:self.mockAirship];

    // Mock JS Action delegate
    self.mockActionJSDelegate = [self mockForClass:[UAActionJSDelegate class]];
    [[[self.mockAirship stub] andReturn:self.mockActionJSDelegate] actionJSDelegate];
}

- (void)testPerformJSDelegateWithDataDismiss {
    // Dismiss and any other message-specific commands should be send to the message JS delegate
    UAWebViewCallData *data = [UAWebViewCallData callDataForURL:[NSURL URLWithString:@"uairship://dismiss/foo-bar-baz"]
                                                       delegate:self.bridge.forwardDelegate];

    UAWebView *webview = [[UAWebView alloc] initWithFrame:CGRectZero];

    [[self.mockMessageJSDelegate expect] callWithData:data withCompletionHandler:OCMOCK_ANY];
    [[self.mockActionJSDelegate reject] callWithData:data withCompletionHandler:OCMOCK_ANY];

    [self.bridge performJSDelegateWithData:data webView:webview];

    [self.mockMessageJSDelegate verify];
    [self.mockActionJSDelegate verify];
}

- (void)testPerformJSDelegateWithDataDefault {
    // Any other recognized commands should default to the action JS delegate
    UAWebViewCallData *data = [UAWebViewCallData callDataForURL:[NSURL URLWithString:@"uairship://close/"]
                                                       delegate:self.bridge.forwardDelegate];

    UAWebView *webview = [[UAWebView alloc] initWithFrame:CGRectZero];

    [[self.mockActionJSDelegate expect] callWithData:data withCompletionHandler:OCMOCK_ANY];
    [[self.mockMessageJSDelegate reject] callWithData:data withCompletionHandler:OCMOCK_ANY];

    [self.bridge performJSDelegateWithData:data webView:webview];

    [self.mockMessageJSDelegate verify];
    [self.mockActionJSDelegate verify];
}

@end
