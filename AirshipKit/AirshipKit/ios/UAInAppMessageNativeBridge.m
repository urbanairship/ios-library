
#import "UAInAppMessageNativeBridge+Internal.h"

@implementation UAInAppMessageNativeBridge

- (void)performJSDelegateWithData:(UAWebViewCallData *)data webView:(UIView *)webView {
    if ([data.url.scheme isEqualToString:UANativeBridgeUAirshipScheme]) {
        if ([data.name isEqualToString:UANativeBridgeDismissCommand]) {
            if (self.messageJSDelegate) {
                [self performAsyncJSCallWithDelegate:self.messageJSDelegate data:data webView:webView];
            }
            return;
        }
    }

    [super performJSDelegateWithData:data webView:webView];
}

@end
