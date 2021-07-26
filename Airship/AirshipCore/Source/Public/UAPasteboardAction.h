/* Copyright Airship and Contributors */

#import "UAAction.h"

/**
 * Sets the pasteboard's string.
 *
 * This action is registered under the names clipboard_action and ^c.
 *
 * Expected argument values: NSString or an NSDictionary with the pasteboard's string
 * under the 'text' key.
 *
 * Valid situations: UASituationLaunchedFromPush,
 * UASituationWebViewInvocation, UASituationManualInvocation,
 * UASituationForegroundInteractiveButton, UASituationBackgroundInteractiveButton,
 * and UASituationAutomation
 *
 * Result value: The arguments value.
 *
 */
API_UNAVAILABLE(tvos)
@interface UAPasteboardAction : NSObject<UAAction>

/**
 * Default registry name for pasteboard action.
 */
extern NSString * const UAPasteboardActionDefaultRegistryName;

/**
 * Default registry alias for pasteboard action.
 */
extern NSString * const UAPasteboardActionDefaultRegistryAlias;

@end
