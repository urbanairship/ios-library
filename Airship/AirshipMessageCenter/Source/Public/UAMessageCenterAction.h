/* Copyright Airship and Contributors */

#import "UAAirshipMessageCenterCoreImport.h"

NS_ASSUME_NONNULL_BEGIN


/**
 * Requests the inbox be displayed.
 *
 * The action will call the UAMessageCenterDisplayDelegate `displayMessageCenterForMessageID:animated:` or
 * `displayMessageCenterAnimated:` depending on whether the message ID is available or not.
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
NS_SWIFT_NAME(MessageCenterAction)
@interface UAMessageCenterAction : NSObject<UAAction>

@end

NS_ASSUME_NONNULL_END
