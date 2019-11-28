/* Copyright Airship and Contributors */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class UAMessageCenterListViewController;
@class UAInboxMessage;

/**
 * Protocol to be implemented by internal message center message view controllers.
 * @deprecated Deprecated – to be removed in SDK version 14.0. Instead use the UAMessageCenterMessageViewController directly.
 */
DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 14.0. Instead use the UAMessageCenterMessageViewController directly.")
@protocol UAMessageCenterMessageViewProtocol


/**
 * The UAInboxMessage being displayed.
 */
@property (nonatomic, strong, readonly) UAInboxMessage *message;

/**
 * Block that will be invoked when this class receives a closeWindow message from the webView.
 */
@property (nonatomic, copy) void (^closeBlock)(BOOL animated);

/**
 * Load a UAInboxMessage by message ID.
 *
 * @param messageID The message ID of the message.
 * @param onlyIfChanged Only load the message if the message has changed
 * @param errorCompletion Called on loading error
 */
- (void)loadMessageForID:(nullable NSString *)messageID onlyIfChanged:(BOOL)onlyIfChanged onError:(nullable void (^)(void))errorCompletion;


@optional

/**
 * Sets a custom message loading indicator view and animation. Will
 * show the default loading indicator and animation if left unset.
 *
 * @param loadingIndicatorView Loading indicator view.
 * @param animations Block to execute upon displaying loading indicator view.
 */
- (void)setLoadingIndicatorView:(UIView *)loadingIndicatorView animations:(void (^)(void))animations;

@end

NS_ASSUME_NONNULL_END

