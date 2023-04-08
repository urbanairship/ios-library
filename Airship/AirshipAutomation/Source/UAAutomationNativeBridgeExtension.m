/* Copyright Airship and Contributors */

#import "UAAutomationNativeBridgeExtension+Internal.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif

@interface UAAutomationNativeBridgeExtension() <UANativeBridgeExtensionDelegate>
@property(nonatomic, strong) UAInAppMessage *message;
@end

@implementation UAAutomationNativeBridgeExtension

+ (instancetype)extensionWithMessage:(UAInAppMessage *)message {
    UAAutomationNativeBridgeExtension *extension = [[self alloc] init];
    extension.message = message;

    return extension;
}

- (NSDictionary * _Nonnull)actionsMetadataForCommand:(UAJavaScriptCommand * _Nonnull)command webView:(WKWebView * _Nonnull)webView {
    return @{};
}

- (void)extendJavaScriptEnvironment:(id<UAJavaScriptEnvironmentProtocol> _Nonnull)js webView:(WKWebView * _Nonnull)webView completionHandler:(void (^ _Nonnull)(void))completionHandler {
    // Message data
    [js addDictionaryGetter:@"getMessageExtras" value:self.message.extras];
    completionHandler();
}

- (id<UANativeBridgeExtensionDelegate>)nativeBridgeExtension {
    return self;
}

@end
