/* Copyright Airship and Contributors */

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
 * Fetch result: UAActionFetchResultNoData
 */
@objc(UAWalletAction)
public class WalletAction : OpenExternalURLAction {
}
