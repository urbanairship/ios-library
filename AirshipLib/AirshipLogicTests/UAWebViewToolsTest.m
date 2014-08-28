
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "UAInbox.h"
#import "UAirship+Internal.h"
#import "UAActionJSDelegate.h"
#import "UAJavaScriptDelegate.h"
#import "UAWebViewTools.h"
#import "UAWebViewCallData.h"

@interface UAWebViewToolsTest : XCTestCase
@property (nonatomic, strong) id mockInboxJSDelegate;
@property (nonatomic, strong) id mockActionJSDelegate;
@property (nonatomic, strong) id mockUserDefinedJSDelegate;
@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) NSURL *basicActionsURL;
@property (nonatomic, strong) NSURL *regularActionsURL;
@property (nonatomic, strong) NSURL *callbackActionURL;
@property (nonatomic, strong) NSURL *otherURL;
@property (nonatomic, strong) NSURL *deprecatedOtherURL;
@end

@implementation UAWebViewToolsTest

- (void)setUp {
    [super setUp];

    self.mockInboxJSDelegate = [OCMockObject mockForProtocol:@protocol(UAInboxJavaScriptDelegate)];
    self.mockActionJSDelegate = [OCMockObject mockForProtocol:@protocol(UAJavaScriptDelegate)];
    self.mockUserDefinedJSDelegate = [OCMockObject mockForProtocol:@protocol(UAJavaScriptDelegate)];
    self.mockAirship = [OCMockObject niceMockForClass:[UAirship class]];

    [[[self.mockAirship stub] andReturn:self.mockAirship] shared];
    [[[self.mockAirship stub] andReturn:self.mockActionJSDelegate] actionJSDelegate];
    [[[self.mockAirship stub] andReturn:self.mockUserDefinedJSDelegate] jsDelegate];
    [UAInbox shared].jsDelegate = self.mockInboxJSDelegate;

    self.basicActionsURL = [NSURL URLWithString:@"uairship://run-basic-actions/?foo=bar&baz=boz"];
    self.regularActionsURL = [NSURL URLWithString:@"uairship://run-actions/some-callback-id?foo=bar"];
    self.otherURL = [NSURL URLWithString:@"uairship://whatever/something-else?yep=nope"];
    self.callbackActionURL = [NSURL URLWithString:@"uairship://run-action-cb/someCallbackID?foo=bar"];
    self.deprecatedOtherURL = [NSURL URLWithString:@"ua://whatever/something-else?yep=nope"];
}

- (void)tearDown {
    [self.mockActionJSDelegate stopMocking];
    [self.mockInboxJSDelegate stopMocking];
    [self.mockUserDefinedJSDelegate stopMocking];

    [UAirship shared].jsDelegate = nil;
    [UAirship shared].actionJSDelegate = nil;

    [super tearDown];
}

- (void)testPerformJSDelegate {
    //a run-actions argument should result in the the callback being dispatched to our internal action JS delegate
    UAWebViewCallData *runActionsData = [UAWebViewCallData callDataForURL:self.regularActionsURL webView:nil];
    [[self.mockActionJSDelegate expect] callWithData:runActionsData withCompletionHandler:[OCMArg any]];
    [UAWebViewTools performJSDelegateWithData:runActionsData];
    [self.mockActionJSDelegate verify];

    //same for run-basic-actions
    UAWebViewCallData *runBasicActionsData = [UAWebViewCallData callDataForURL:self.basicActionsURL webView:nil];
    [[self.mockActionJSDelegate expect] callWithData:runBasicActionsData withCompletionHandler:[OCMArg any]];
    [UAWebViewTools performJSDelegateWithData:runBasicActionsData];
    [self.mockActionJSDelegate verify];

    //same for run-action-cb
    UAWebViewCallData *runActionsCBData = [UAWebViewCallData callDataForURL:self.callbackActionURL webView:nil];
    [[self.mockActionJSDelegate expect] callWithData:runActionsCBData withCompletionHandler:[OCMArg any]];
    [UAWebViewTools performJSDelegateWithData:runActionsCBData];
    [self.mockActionJSDelegate verify];

    //ua urls should be dispatched to the (deprecated) inbox js delegate
    UAWebViewCallData *deprecatedData = [UAWebViewCallData callDataForURL:self.deprecatedOtherURL webView:nil];
    [[self.mockInboxJSDelegate expect] callbackArguments:deprecatedData.arguments withOptions:deprecatedData.options];
    [UAWebViewTools performJSDelegateWithData:deprecatedData];
    [self.mockInboxJSDelegate verify];

    //otherwise uairship urls should be dispatched to the the new user js delegate
    UAWebViewCallData *data = [UAWebViewCallData callDataForURL:self.otherURL webView:nil];
    [[self.mockUserDefinedJSDelegate expect] callWithData:data withCompletionHandler:[OCMArg any]];
    [UAWebViewTools performJSDelegateWithData:data];
    [self.mockUserDefinedJSDelegate verify];
}

@end
