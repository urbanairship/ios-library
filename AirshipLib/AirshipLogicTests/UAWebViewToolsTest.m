
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "UAInbox.h"
#import "UAirship+Internal.h"
#import "UAActionJSDelegate.h"
#import "UAJavaScriptDelegate.h"
#import "UAWebViewTools.h"
#import "UAWebViewCallData.h"

@interface UAWebViewToolsTest : XCTestCase
@property(nonatomic, strong) id mockInboxJSDelegate;
@property(nonatomic, strong) id mockActionJSDelegate;
@property(nonatomic, strong) id mockUserDefinedJSDelegate;
@property(nonatomic, strong) id mockAirship;
@property(nonatomic, strong) NSURL *basicActionsURL;
@property(nonatomic, strong) NSURL *regularActionsURL;
@property(nonatomic, strong) NSURL *callbackActionURL;
@property(nonatomic, strong) NSURL *otherURL;
@property(nonatomic, strong) NSURL *deprecatedOtherURL;
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
    [[self.mockActionJSDelegate expect] callWithData:[OCMArg any] withCompletionHandler:[OCMArg any]];
    [UAWebViewTools performJSDelegate:nil url:self.regularActionsURL];
    [self.mockActionJSDelegate verify];

    //same for run-basic-actions
    [[self.mockActionJSDelegate expect] callWithData:[OCMArg any] withCompletionHandler:[OCMArg any]];
    [UAWebViewTools performJSDelegate:nil url:self.basicActionsURL];
    [self.mockActionJSDelegate verify];

    //same for run-action-cb
    [[self.mockActionJSDelegate expect] callWithData:[OCMArg any] withCompletionHandler:[OCMArg any]];
    [UAWebViewTools performJSDelegate:nil url:self.callbackActionURL];
    [self.mockActionJSDelegate verify];

    //ua urls should be dispatched to the (deprecated) inbox js delegate
    [[self.mockInboxJSDelegate expect] callbackArguments:[OCMArg any] withOptions:[OCMArg any]];
    [UAWebViewTools performJSDelegate:nil url:self.deprecatedOtherURL];
    [self.mockInboxJSDelegate verify];

    //otherwise uairship urls should be dispatched to the the new user js delegate
    [[self.mockUserDefinedJSDelegate expect] callWithData:[OCMArg any] withCompletionHandler:[OCMArg any]];
    [UAWebViewTools performJSDelegate:nil url:self.otherURL];
    [self.mockUserDefinedJSDelegate verify];
}

@end
