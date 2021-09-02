/* Copyright Airship and Contributors */

#import "UAAutomationNativeBridgeExtension+Internal.h"

#if __has_include("AirshipCore/AirshipCore-Swift.h")
@import AirshipCore;
#elif __has_include("Airship/Airship-Swift.h")
#import <Airship/Airship-Swift.h>
#endif

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
