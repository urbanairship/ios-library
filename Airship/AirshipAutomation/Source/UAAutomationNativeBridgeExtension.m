/* Copyright Airship and Contributors */

#import "UAAutomationNativeBridgeExtension+Internal.h"

@interface UAAutomationNativeBridgeExtension()
@property(nonatomic, strong) UAInAppMessage *message;
@end

@implementation UAAutomationNativeBridgeExtension

+ (instancetype)extensionWithMessage:(UAInAppMessage *)message {
    UAAutomationNativeBridgeExtension *extension = [[self alloc] init];
    extension.message = message;

    return extension;
}

- (void)extendJavaScriptEnvironment:(UAJavaScriptEnvironment *)js webView:(WKWebView *)webView {
    // Message data
    [js addDictionaryGetter:@"getMessageExtras" value:self.message.extras];
}

@end
