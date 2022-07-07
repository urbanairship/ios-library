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
public class DeepLinkAction : NSObject, Action {

    public func acceptsArguments(_ arguments: ActionArguments) -> Bool {
        switch (arguments.situation) {
        case .backgroundPush:
            return false
        case .backgroundInteractiveButton:
            return false
        default:
            return parseURL(arguments) != nil
        }
    }

    public func perform(with arguments: ActionArguments,
                        completionHandler: @escaping UAActionCompletionHandler) {
        
        guard let url = parseURL(arguments) else {
            completionHandler(ActionResult.empty())
            return
        }
        
        Airship.shared.deepLink(url) { result in
            if (result) {
                completionHandler(ActionResult.empty())
            } else {
                self.openURL(url, completionHandler: completionHandler)
            }
        }
    }
    
    private func openURL(_ url: URL, completionHandler: @escaping UAActionCompletionHandler) {
        UADispatcher.main.dispatchAsync {
            guard Airship.shared.urlAllowList.isAllowed(url, scope: .openURL) else {
                AirshipLogger.error("URL \(url) not allowed. Unable to open url.")
                completionHandler(ActionResult(error: AirshipErrors.error("URL \(url) not allowed")))
                return
            }
            #if !os(watchOS)
            UIApplication.shared.open(url, options: [:]) { success in
                if (success) {
                    completionHandler(ActionResult.empty())
                } else {
                    completionHandler(ActionResult(error: AirshipErrors.error("Failed to open url \(url)")))
                }
            }
            #else
            WKExtension.shared().openSystemURL(url)
            #endif
        }
    }
    
    private func parseURL(_ arguments: ActionArguments) -> URL? {
        if let value = arguments.value as? String {

            if let url = Utils.parseURL(value) {
                return url
            }
               
        }
        
        if let value = arguments.value as? URL {
            return value
        }
        
        return nil
    }
}

