/* Copyright 2017 Urban Airship and Contributors */

#import <WebKit/WebKit.h>
#import "UAWKWebViewDelegate.h"
#import "UAMessageCenterMessageViewProtocol.h"

@class UAInboxMessage;
@class UADefaultMessageCenterStyle;

/**
 * Default implementation of a view controller for reading Message Center messages.
 */
@interface UAMessageCenterMessageViewController : UIViewController <UAWKWebViewDelegate, UAMessageCenterMessageViewProtocol>

- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_UNAVAILABLE;

@end
