/* Copyright Airship and Contributors */

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import "UAMessageCenterMessageViewProtocol.h"

#import "UAAirshipMessageCenterCoreImport.h"

/**
 * Default implementation of a view controller for reading Message Center messages.
 */
@interface UAMessageCenterMessageViewController : UIViewController <UAMessageCenterMessageViewProtocol>

/**
* `initWithCoder:` is not available. Use the `initWithNibName:bundle:` initializer method.
* :nodoc:
*/
- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_UNAVAILABLE;

@end
