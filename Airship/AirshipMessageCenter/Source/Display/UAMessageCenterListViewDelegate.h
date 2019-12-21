/* Copyright Airship and Contributors */

NS_ASSUME_NONNULL_BEGIN

/**
 * Protocol for delegating message list UI state handling.
 */
@protocol UAMessageCenterListViewDelegate <NSObject>

/**
 * Whether the list view should deselect active cells when appearing. If implemented, this
 * callback will override the embedded tableView's default behavior.
 *
 * @return `YES` if the list view should deselect active cells when appearing, `NO` otherwise.
 */
- (BOOL)shouldClearSelectionOnViewWillAppear;

@end

NS_ASSUME_NONNULL_END
