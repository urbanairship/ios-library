
#import <Foundation/Foundation.h>
#import "UAJavaScriptDelegate.h"

/**
 * Library-internal implementation of UAJavaScriptDelegate.
 *
 * This class exclusively handles UAJavaScriptDelegate calls with the
 * run-action-cb, run-actions and run-basic-actions commands.
 */
@interface UAActionJSDelegate : NSObject<UAJavaScriptDelegate>

@end
