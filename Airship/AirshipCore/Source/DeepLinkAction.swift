/* Copyright Airship and Contributors */

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
 * Error: Iif the URL could not be opened
 *
 * Fetch result: UAActionFetchResultNoData
 */
@objc(UADeepLinkAction)
public class DeepLinkAction : NSObject, UAAction {

    public func acceptsArguments(_ arguments: UAActionArguments) -> Bool {
        switch (arguments.situation) {
        case .backgroundPush:
            return false
        case .backgroundInteractiveButton:
            return false
        default:
            return parseURL(arguments) != nil
        }
    }

    public func perform(with arguments: UAActionArguments,
                        completionHandler: @escaping UAActionCompletionHandler) {
        
        guard let url = parseURL(arguments) else {
            completionHandler(UAActionResult.empty())
            return
        }
        
        UAirship.shared().deepLink(url) { result in
            if (result) {
                completionHandler(UAActionResult.empty())
            } else {
                self.openURL(url, completionHandler: completionHandler)
            }
        }
    }
    
    private func openURL(_ url: URL, completionHandler: @escaping UAActionCompletionHandler) {
        UADispatcher.main.dispatchAsync {
            guard UAirship.shared().urlAllowList.isAllowed(url, scope: .openURL) else {
                AirshipLogger.error("URL \(url) not allowed. Unable to open url.")
                completionHandler(UAActionResult(error: AirshipErrors.error("URL \(url) not allowed")))
                return
            }
            UIApplication.shared.open(url, options: [:]) { success in
                if (success) {
                    completionHandler(UAActionResult.empty())
                } else {
                    completionHandler(UAActionResult(error: AirshipErrors.error("Failed to open url \(url)")))
                }
            }
        }
    }
    
    private func parseURL(_ arguments: UAActionArguments) -> URL? {
        if let value = arguments.value as? String {
            return URL(string: value)
        }
        
        if let value = arguments.value as? URL {
            return value
        }
        
        return nil
    }
}

