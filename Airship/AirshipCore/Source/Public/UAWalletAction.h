/* Copyright Airship and Contributors */

#import "UAOpenExternalURLAction.h"

/**
 * Opens a wallet URL, either in safari or using custom URL schemes. This action is
 * registered under the names ^w and wallet_action.
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
API_UNAVAILABLE(tvos)
@interface UAWalletAction : UAOpenExternalURLAction

/**
 * Default registry name for wallet action.
 */
extern NSString * const UAWalletActionDefaultRegistryName;

/**
 * Default registry alias for wallet action.
 */
extern NSString * const UAWalletActionDefaultRegistryAlias;

@end
