/* Copyright Airship and Contributors */

#import "UAOpenExternalURLAction.h"

/**
 * Opens a deep link URL. This action is registered under
 * the names ^d and deep_link_action.
 *
 * Expected argument values: NSString
 *
 * Valid situations: UASituationForegroundPush, UASituationLaunchedFromPush
 * UASituationWebViewInvocation, UASituationForegroundInteractiveButton,
 * UASituationManualInvocation, and UASituationAutomation
 *
 * Result value: An NSString representation of the input
 *
 * Error: `UAOpenExternalURLActionErrorCodeURLFailedToOpen` if the URL could not be opened
 *
 * Fetch result: UAActionFetchResultNoData
 */
@interface UADeepLinkAction : UAOpenExternalURLAction

/**
* Default registry name for deep link action.
*/
extern NSString * const UADeepLinkActionDefaultRegistryName;

/**
* Default registry alias for deep link action.
*/
extern NSString * const UADeepLinkActionDefaultRegistryAlias;

/**
* Default registry name for deep link action.
*
* @deprecated Deprecated – to be removed in SDK version 14.0. Please use UADeepLinkActionDefaultRegistryName.
*/
extern NSString * const kUADeepLinkActionDefaultRegistryName DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 14.0. Please use UADeepLinkActionDefaultRegistryName.");

/**
* Default registry alias for deep link action.
*
* @deprecated Deprecated – to be removed in SDK version 14.0. Please use UADeepLinkActionDefaultRegistryAlias.
*/
extern NSString * const kUADeepLinkActionDefaultRegistryAlias DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 14.0. Please use UADeepLinkActionDefaultRegistryAlias.");

@end
