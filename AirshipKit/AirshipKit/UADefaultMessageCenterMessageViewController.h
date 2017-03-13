/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <UIKit/UIKit.h>
#import "UARichContentWindow.h"

@class UAInboxMessage;
@class UADefaultMessageCenterStyle;

/**
 * Default implementation of a view controller for reading Message Center messages.
 *
 * @deprecated Deprecated - to be removed in SDK version 9.0 - please use UAMessageCenterMessageViewController
 */

DEPRECATED_MSG_ATTRIBUTE("Deprecated - to be removed in SDK version 9.0 - please use UAMessageCenterMessageViewController")
@interface UADefaultMessageCenterMessageViewController : UIViewController

/**
 * The UAInboxMessage being displayed.
 *
 * @deprecated Deprecated - to be removed in SDK version 9.0 - please use UAMessageCenterMessageViewController
 */
@property (nonatomic, strong) UAInboxMessage *message DEPRECATED_MSG_ATTRIBUTE("Deprecated - to be removed in SDK version 9.0 - please use UAMessageCenterMessageViewController");

/**
 * An optional predicate for filtering messages.
 *
 * @deprecated Deprecated - to be removed in SDK version 9.0 - please use UAMessageCenterMessageViewController
 */
@property (nonatomic, strong) NSPredicate *filter DEPRECATED_MSG_ATTRIBUTE("Deprecated - to be removed in SDK version 9.0 - please use UAMessageCenterMessageViewController");

/**
 * Block that will be invoked when this class receives a closeWindow message from the webView.
 *
 * @deprecated Deprecated - to be removed in SDK version 9.0 - please use UAMessageCenterMessageViewController
 */
@property (nonatomic, copy) void (^closeBlock)(BOOL animated) DEPRECATED_MSG_ATTRIBUTE("Deprecated - to be removed in SDK version 9.0 - please use UAMessageCenterMessageViewController");

/**
 * Load a UAInboxMessage at a particular index in the message list.
 * @param index The corresponding index in the message list as an integer.
 *
 * @deprecated Deprecated - to be removed in SDK version 9.0 - please use UAMessageCenterMessageViewController
 */
- (void)loadMessageAtIndex:(NSUInteger)index DEPRECATED_MSG_ATTRIBUTE("Deprecated - to be removed in SDK version 9.0 - please use UAMessageCenterMessageViewController");

/**
 * Load a UAInboxMessage by message ID.
 * @param mid The message ID as an NSString.
 *
 * @deprecated Deprecated - to be removed in SDK version 9.0 - please use UAMessageCenterMessageViewController
 */
- (void)loadMessageForID:(NSString *)mid DEPRECATED_MSG_ATTRIBUTE("Deprecated - to be removed in SDK version 9.0 - please use UAMessageCenterMessageViewController");

@end
