
#import "UAAction.h"

/**
 * Stores or displays an in-app message.
 *
 * This action is registered under the names com.urbanairship.in_app and ^i.
 *
 * Expected argument value is an in-app message payload in NSDictionary format.
 *
 * Valid situations: UASituationForegroundPush, UASituationBackgroundPush,
 * UASituationWebViewInvocation, UASituationManualInvocation,
 * UASituationForegroundInteractiveButton and UASituationForegroundBackgroundButton
 *
 * Default predicate: Rejects situation UASituationLaunchedFromPush.
 *
 * Result value: nil.
 *
 */
@interface UAInAppMessageAction : UAAction

@end
