/* Copyright Airship and Contributors */

NS_ASSUME_NONNULL_BEGIN

/**
 * Protocol for delegating message list behavior.
 */
NS_SWIFT_NAME(MessageCenterListViewDelegate)
@protocol UAMessageCenterListViewDelegate <NSObject>

/**
 * Whether the list view should deselect active cells when appearing. If implemented, this
 * callback will override the embedded tableView's default behavior.
 *
 * @return `YES` if the list view should deselect active cells when appearing, `NO` otherwise.
 */
- (BOOL)shouldClearSelectionOnViewWillAppear;

/**
 * Informs the delegate that a message was selected in the list view controller.

 * @param messageID The selected message ID, or nil if a message is no longer selected.
 */
- (void)didSelectMessageWithID:(nullable NSString *)messageID;

@end

NS_ASSUME_NONNULL_END
