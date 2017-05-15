/* Copyright 2017 Urban Airship and Contributors */

NS_ASSUME_NONNULL_BEGIN

@class UADefaultMessageCenterListViewController;
@class UAInboxMessage;

/**
 * Protocol to be implemented by internal message center message view controllers.
 */
@protocol UAMessageCenterMessageViewProtocol

/**
 * The UAInboxMessage being displayed.
 */
@property (nonatomic, strong, readonly) UAInboxMessage *message;

///**
// * An optional predicate for filtering messages.
// */
//@property (nonatomic, strong) NSPredicate *filter;
//
/**
 * Block that will be invoked when this class receives a closeWindow message from the webView.
 */
@property (nonatomic, copy) void (^closeBlock)(BOOL animated);

/**
 * Load a UAInboxMessage.
 * @param message The message to load and display.
 * @param onlyIfChanged Only load the message if it is different from the currently displayed message
 */

- (void)loadMessage:(nullable UAInboxMessage *)message onlyIfChanged:(BOOL)onlyIfChanged;

@end

NS_ASSUME_NONNULL_END
