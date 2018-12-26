
#import "UAInAppMessageNativeBridge+Internal.h"

@implementation UAInAppMessageNativeBridge

- (void)performJSDelegateWithData:(UAWebViewCallData *)data webView:(UIView *)webView {
    if ([data.url.scheme isEqualToString:@"uairship"]) {
        if ([data.name isEqualToString:@"dismiss"]) {
            if (self.messageJSDelegate) {
                [self performAsyncJSCallWithDelegate:self.messageJSDelegate data:data webView:webView];
            }
            return;
        }
    }

    [super performJSDelegateWithData:data webView:webView];
}

@end
