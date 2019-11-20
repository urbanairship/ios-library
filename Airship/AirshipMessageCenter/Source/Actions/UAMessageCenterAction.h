/* Copyright Airship and Contributors */

#import "UAAction.h"

NS_ASSUME_NONNULL_BEGIN


/**
 * Requests the inbox be displayed.
 *
 * The action will call the UAInboxDelegate `showInboxMessage:` or `showInbox` depending on if the message ID is available or not.
 *
 * This action is registered under the name `_uamid`.
 *
 * Expected argument value is an inbox message ID as an NSString, or nil.
 *
 * Valid situations:  UASituationLaunchedFromPush, UASituationWebViewInvocation, UASituationManualInvocation,
 * UASituationForegroundInteractiveButton, and UASituationAutomation
 *
 * Result value: nil
 */
@interface UAMessageCenterAction : UAAction

@end

NS_ASSUME_NONNULL_END
