/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "UAInboxMessage.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Delegate protocol for presenting message center messages.
 */
@protocol UAMessageCenterMessagePresentationDelegate <NSObject>

/**
 * Present the message with the corresponding identifier.
 */
- (void)presentMessage:(UAInboxMessage *)message;

/**
 * Dismiss the currently displayed message.
 */
- (void)dismissMessage;

@end

NS_ASSUME_NONNULL_END
