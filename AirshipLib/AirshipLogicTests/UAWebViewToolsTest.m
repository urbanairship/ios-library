
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
@property(nonatomic, strong) NSURL *basicActionURL;
@property(nonatomic, strong) NSURL *regularActionURL;
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

    self.basicActionURL = [NSURL URLWithString:@"uairship://run-basic-action/?foo=bar&baz=boz"];
    self.regularActionURL = [NSURL URLWithString:@"uairship://run-action/some-callback-id?foo=bar"];
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

    //a run-action argument should result in the the callback being dispatched to our internal action JS delegate
    [[self.mockActionJSDelegate expect] callWithData:[OCMArg any] withCompletionHandler:[OCMArg any]];
    [UAWebViewTools performJSDelegate:nil url:self.regularActionURL];
    [self.mockActionJSDelegate verify];

    //same for run-basic-action
    [[self.mockActionJSDelegate expect] callWithData:[OCMArg any] withCompletionHandler:[OCMArg any]];
    [UAWebViewTools performJSDelegate:nil url:self.basicActionURL];
    [self.mockActionJSDelegate verify];

    //ua urls should be dispatched to the (deprecated) inbox js delegate
    [[self.mockInboxJSDelegate expect] callbackArguments:[OCMArg any] withOptions:[OCMArg any]];

    [UAWebViewTools performJSDelegate:nil url:self.otherURL];
    [self.mockInboxJSDelegate verify];
    [self.mockUserDefinedJSDelegate verify];

    //otherwise uairship urls should be dispatched to the the new user js delegate
    [[self.mockUserDefinedJSDelegate expect] callWithData:[OCMArg any] withCompletionHandler:[OCMArg any]];
    [[self.mockUserDefinedJSDelegate expect] callWithData:[OCMArg any] withCompletionHandler:[OCMArg any]];

    [UAWebViewTools performJSDelegate:nil url:self.deprecatedOtherURL];
    [self.mockInboxJSDelegate verify];
    [self.mockUserDefinedJSDelegate verify];

}

@end
