/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UAAutomationNativeBridgeExtension+Internal.h"
#import "UAirship+Internal.h"
#import "UAUtils+Internal.h"
#import "UAInAppMessage.h"
#import "UAInAppMessageCustomDisplayContent.h"

@interface UAAutomationNativeBridgeExtensionTest : UAAirshipBaseTest
@property (nonatomic, strong) UAAutomationNativeBridgeExtension *extension;
@property (nonatomic, strong) UAInAppMessage *message;
@property (nonatomic, strong) id mockWebView;
@end

@implementation UAAutomationNativeBridgeExtensionTest

- (void)setUp {
    self.message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder * _Nonnull builder) {
        builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
        builder.extras = @{@"foo" : @"bar"};
    }];

    self.extension = [UAAutomationNativeBridgeExtension extensionWithMessage:self.message];
    self.mockWebView = [self mockForClass:[WKWebView class]];
}

/**
 * Test the JavaScript environment is extended with the message extras
 */
- (void)testExtendJavaScriptEnvironment {
    NSURL *URL = [NSURL URLWithString:@"https://foo.urbanairship.com/whatever.html"];
    [[[self.mockWebView stub] andReturn:URL] URL];

    // Expect the environment changes
    id javaScriptEnvironment = [self mockForClass:[UAJavaScriptEnvironment class]];
    [[javaScriptEnvironment expect] addDictionaryGetter:@"getMessageExtras" value:self.message.extras];

    // Extend the environment
    [self.extension extendJavaScriptEnvironment:javaScriptEnvironment webView:self.mockWebView];

    // Verify
    [javaScriptEnvironment verify];
}

/**
 * Test the JavaScript environment is extended with the message extras
 */
- (void)testExtendJavaScriptEnvironmentNilExtras {
    self.message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder * _Nonnull builder) {
        builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
        builder.extras = nil;
    }];

    self.extension = [UAAutomationNativeBridgeExtension extensionWithMessage:self.message];

    NSURL *URL = [NSURL URLWithString:@"https://foo.urbanairship.com/whatever.html"];
    [[[self.mockWebView stub] andReturn:URL] URL];

    // Expect the environment changes
    id javaScriptEnvironment = [self mockForClass:[UAJavaScriptEnvironment class]];
    [[javaScriptEnvironment expect] addDictionaryGetter:@"getMessageExtras" value:self.message.extras];

    // Extend the environment
    [self.extension extendJavaScriptEnvironment:javaScriptEnvironment webView:self.mockWebView];

    // Verify
    [javaScriptEnvironment verify];
}

@end
