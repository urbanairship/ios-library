/* Copyright Airship and Contributors */

NS_ASSUME_NONNULL_BEGIN

/**
 * Protocol for delegating message list UI state handling.
 */
@protocol UAMessageCenterListViewDelegate <NSObject>

/**
 * Whether the list view should deselect active cells when appearing. Useful
 * In split view and other compound UI contexts where desired cell selection
 * behavior is dependent on the state of its outer UI context.
 *
 * @return `YES` if the list view should deselect active cells when appearing, `NO` otherwise.
 */
- (BOOL)shouldDeselectActiveCellWhenAppearing;

@end

NS_ASSUME_NONNULL_END
