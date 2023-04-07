/* Copyright Airship and Contributors */

/// Opens a deep link URL. This action is registered under
/// the names ^d and deep_link_action.
///
/// Expected argument values: NSString
///
/// Valid situations: UASituationForegroundPush, UASituationLaunchedFromPush
/// UASituationWebViewInvocation, UASituationForegroundInteractiveButton,
/// UASituationManualInvocation, and UASituationAutomation
///
/// Result value: An NSString representation of the input
///
/// Error: Iif the URL could not be opened
///
/// Fetch result: UAActionFetchResultNoData
@objc(UADeepLinkAction)
public class DeepLinkAction: NSObject, Action {

    public func acceptsArguments(_ arguments: ActionArguments) -> Bool {
        switch arguments.situation {
        case .backgroundPush:
            return false
        case .backgroundInteractiveButton:
            return false
        default:
            return parseURL(arguments) != nil
        }
    }

    public func perform(
        with arguments: ActionArguments
    ) async -> ActionResult {

        guard let url = parseURL(arguments) else {
            return ActionResult.empty()
        }

        let result = await Airship.shared.deepLink(url)
        
        if result {
            return ActionResult.empty()
        } else {
            return await self.openURL(url)
        }
    }

    private func openURL(
        _ url: URL) async -> ActionResult {
            guard Airship.shared.urlAllowList.isAllowed(url, scope: .openURL)
            else {
                AirshipLogger.error(
                    "URL \(url) not allowed. Unable to open url."
                )
                return ActionResult(
                    error: AirshipErrors.error("URL \(url) not allowed")
                )
            }
    #if !os(watchOS)
            let success = await UIApplication.shared.open(url, options: [:])
            
            if success {
                return ActionResult.empty()
            } else {
                return ActionResult(
                    error: AirshipErrors.error(
                        "Failed to open url \(url)"
                    )
                )
            }
            
    #else
            WKExtension.shared().openSystemURL(url)
    #endif
            
    }

    private func parseURL(_ arguments: ActionArguments) -> URL? {
        if let value = arguments.value as? String {

            if let url = AirshipUtils.parseURL(value) {
                return url
            }

        }

        if let value = arguments.value as? URL {
            return value
        }

        return nil
    }
}
