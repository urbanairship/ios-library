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
@interface UAPasteboardAction : UAAction

/**
 * Default registry name for pasteboard action.
 */
extern NSString * const UAPasteboardActionDefaultRegistryName;

/**
 * Default registry alias for pasteboard action.
 */
extern NSString * const UAPasteboardActionDefaultRegistryAlias;

/**
 * Default registry name for pasteboard action.
 *
 * @deprecated Deprecated – to be removed in SDK version 14.0. Please use UAPasteboardActionDefaultRegistryName.
*/
extern NSString * const kUAPasteboardActionDefaultRegistryName DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 14.0. Please use UAPasteboardActionDefaultRegistryName.");

/**
 * Default registry alias for pasteboard action.
 *
 * @deprecated Deprecated – to be removed in SDK version 14.0. Please use UAPasteboardActionDefaultRegistryAlias.
*/
extern NSString * const kUAPasteboardActionDefaultRegistryAlias DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 14.0. Please use UAPasteboardActionDefaultRegistryAlias.");

@end
