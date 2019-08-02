
#import "UAInAppMessageNativeBridge+Internal.h"

@implementation UAInAppMessageNativeBridge

- (void)performJSDelegateWithData:(UAWebViewCallData *)data webView:(UIView *)webView {
    if ([data.url.scheme isEqualToString:UANativeBridgeUAirshipScheme]) {
        if ([data.name isEqualToString:UANativeBridgeDismissCommand]) {
            id <UAJavaScriptDelegate> messageJSDelegate = self.messageJSDelegate;
            if (messageJSDelegate) {
                [self performAsyncJSCallWithDelegate:messageJSDelegate data:data webView:webView];
            }
            return;
        }
    }

    [super performJSDelegateWithData:data webView:webView];
}

@end
