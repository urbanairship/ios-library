/* Copyright Airship and Contributors */

#import "UAAutomationNativeBridgeExtension+Internal.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
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

- (void)extendJavaScriptEnvironment:(id<UAJavaScriptEnvironmentProtocol>)js webView:(WKWebView *)webView {
    // Message data
    [js addDictionaryGetter:@"getMessageExtras" value:self.message.extras];
}

@end
