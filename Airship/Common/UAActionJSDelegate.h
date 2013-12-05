
#import <Foundation/Foundation.h>
#import "UAJavaScriptDelegate.h"

/**
 * Library-internal implementation of UAJavaScriptDelegate.
 *
 * This class exclusively handles UIWebView JS callbacks with the
 * run-action and run-basic-action arguments.
 */
@interface UAActionJSDelegate : NSObject<UAJavaScriptDelegate>

@end
