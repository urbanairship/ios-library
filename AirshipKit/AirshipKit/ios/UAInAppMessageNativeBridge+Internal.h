
#import "UAWKWebViewNativeBridge.h"
#import "UABaseNativeBridge+Internal.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * A native bridge for HTML-based in-app messages.
 */
@interface UAInAppMessageNativeBridge : UAWKWebViewNativeBridge

/**
 * The message JavaScript delegate, for handling native bridge calls specific to in-app messaging.
 */
@property (nonatomic, weak, nullable) id <UAJavaScriptDelegate> messageJSDelegate;

@end

NS_ASSUME_NONNULL_END
