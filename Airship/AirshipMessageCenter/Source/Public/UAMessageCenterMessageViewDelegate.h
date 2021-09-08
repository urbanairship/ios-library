/* Copyright Airship and Contributors */

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Protocol for delegating the handling of message view loading and native bridge events.
 */
NS_SWIFT_NAME(MessageCenterMessageViewDelegate)
@protocol UAMessageCenterMessageViewDelegate <NSObject>

/**
 * Called when the message load begins.
 * @param messageID The messageID.
 */
- (void)messageLoadStarted:(NSString *)messageID;

/**
 * Called when the message load has succeeded.
 * @param messageID The messageID.
 */
- (void)messageLoadSucceeded:(NSString *)messageID;

/**
 * Called when the message load has failed.
 * @param messageID The messageID.
 * @param error The error.
 */
- (void)messageLoadFailed:(NSString *)messageID error:(NSError *)error;

/**
 * Called when the message is closed from within the native bridge.
 * @param messageID The messageID.
 */
- (void)messageClosed:(NSString *)messageID;

@end

NS_ASSUME_NONNULL_END
