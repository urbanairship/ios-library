/* Copyright Airship and Contributors */

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import "UAMessageCenterMessageViewProtocol.h"

#import "UAAirshipMessageCenterCoreImport.h"

/**
 * Default implementation of a view controller for reading Message Center messages.
 */
DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 14.0. Instead use UADefaultMessageCenterMessageViewController.")
@interface UAMessageCenterMessageViewController : UIViewController <UAMessageCenterMessageViewProtocol>

- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_UNAVAILABLE;

@end
