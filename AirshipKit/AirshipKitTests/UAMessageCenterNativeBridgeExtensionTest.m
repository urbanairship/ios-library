/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UAMessageCenterNativeBridgeExtension.h"
#import "UAirship+Internal.h"
#import "UAInbox.h"
#import "UAInboxMessageList.h"
#import "UAUser.h"
#import "UAInboxMessage.h"
#import "UAActionArguments.h"
#import "UAUserData+Internal.h"
#import "UAUtils+Internal.h"

@interface UAMessageCenterNativeBridgeExtensionTest : UABaseTest
@property (nonatomic, strong) UAMessageCenterNativeBridgeExtension *extension;

@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) id mockMessageList;
@property (nonatomic, strong) id mockUser;
@property (nonatomic, strong) id mockInbox;
@property (nonatomic, strong) id mockWKWebView;
@end

@implementation UAMessageCenterNativeBridgeExtensionTest

- (void)setUp {
    self.extension = [[UAMessageCenterNativeBridgeExtension alloc] init];

    // Mock WKWebView
    self.mockWKWebView = [self mockForClass:[WKWebView class]];

    // Mock UAUser
    self.mockUser = [self mockForClass:[UAUser class]];

    // Mock the inbox and message list
    self.mockInbox = [self mockForClass:[UAInbox class]];
    self.mockMessageList = [self mockForClass:[UAInboxMessageList class]];
    [[[self.mockInbox stub] andReturn:self.mockMessageList] messageList];

    // Mock Airship
    self.mockAirship = [self mockForClass:[UAirship class]];
    [UAirship setSharedAirship:self.mockAirship];
    [[[self.mockAirship stub] andReturn:self.mockUser] inboxUser];
    [[[self.mockAirship stub] andReturn:self.mockInbox] inbox];
}

/**
 * Test the JavaScript environment is extended with the message and user if the web view's URL maps to a message.
 */
- (void)testExtendJavaScriptEnvironment {
    NSURL *URL = [NSURL URLWithString:@"https://foo.urbanairship.com/whatever.html"];
    [[[self.mockWKWebView stub] andReturn:URL] URL];

    // Mock the message
    id message = [self mockForClass:[UAInboxMessage class]];
    NSDate *messageSent = [NSDate date];
    [[[message stub] andReturn:@"messageID"] messageID];
    [[[message stub] andReturn:@"messageTitle"] title];
    [[[message stub] andReturn:messageSent] messageSent];
    [[[message stub] andReturnValue:@(YES)] unread];

    // Assciate the URL with the message
    [[[self.mockMessageList stub] andReturn:message] messageForBodyURL:URL];

    // Add user credentials
    UAUserData *userData = [UAUserData dataWithUsername:@"username" password:@"password"];
    [[[self.mockUser stub] andReturn:userData] getUserDataSync];

    NSString *messageSentString = [[UAUtils ISODateFormatterUTC] stringFromDate:messageSent];
    double messageSentMS = [messageSent timeIntervalSince1970] * 1000;

    // Expect the environment changes
    id javaScriptEnvironment = [self mockForClass:[UAJavaScriptEnvironment class]];
    [[javaScriptEnvironment expect] addStringGetter:@"getUserId" value:@"username"];
    [[javaScriptEnvironment expect] addStringGetter:@"getMessageId" value:@"messageID"];
    [[javaScriptEnvironment expect] addStringGetter:@"getMessageTitle" value:@"messageTitle"];
    [[javaScriptEnvironment expect] addStringGetter:@"getMessageSentDate" value:messageSentString];
    [[javaScriptEnvironment expect] addNumberGetter:@"getMessageSentDateMS" value:@(messageSentMS)];

    // Extend the environment
    [self.extension extendJavaScriptEnvironment:javaScriptEnvironment webView:self.mockWKWebView];

    // Verify
    [javaScriptEnvironment verify];
}

/**
 * Test the action metadata includes the message if the web view's URL maps to a message.
 */
- (void)testActionMetadata {
    NSURL *URL = [NSURL URLWithString:@"https://foo.urbanairship.com/whatever.html"];
    [[[self.mockWKWebView stub] andReturn:URL] URL];

    // Mock the message
    UAInboxMessage *mockMessage = [self mockForClass:[UAInboxMessage class]];
    OCMStub([mockMessage messageID]).andReturn(@"MCRAP");

    // Assciate the URL with the message
    [[[self.mockMessageList stub] andReturn:mockMessage] messageForBodyURL:URL];

    // Extend the environment
    NSDictionary *metadata = [self.extension actionsMetadataForCommand:[UAJavaScriptCommand commandForURL:URL]
                                                               webView:self.mockWKWebView];

    NSDictionary *expected = @{ UAActionMetadataInboxMessageIDKey : mockMessage.messageID };
    XCTAssertEqualObjects(expected, metadata);
}

/**
 * Test the metadata is an empty map if no message is associated with the web view's URL.
 */
- (void)testActionMetadataNoMessage {
    NSURL *URL = [NSURL URLWithString:@"https://foo.urbanairship.com/whatever.html"];
    [[[self.mockWKWebView stub] andReturn:URL] URL];
    // Extend the environment
    NSDictionary *metadata = [self.extension actionsMetadataForCommand:[UAJavaScriptCommand commandForURL:URL]
                                                               webView:self.mockWKWebView];

    NSDictionary *expected = @{};
    XCTAssertEqualObjects(expected, metadata);
}

@end
