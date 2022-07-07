/* Copyright Airship and Contributors */

/**
 * Opens a URL, either in safari or using custom URL schemes. This action is
 * registered under the names ^u and open_external_url_action.
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
@objc(UAOpenExternalURLAction)
public class OpenExternalURLAction : NSObject, Action {
    
    @objc
    public static let name = "open_external_url_action"
    
    @objc
    public static let shortName = "^u"

    public func acceptsArguments(_ arguments: ActionArguments) -> Bool {
        switch (arguments.situation) {
        case .backgroundPush:
            return false
        case .backgroundInteractiveButton:
            return false
        default:
            guard let url = parseURL(arguments) else {
                return false
            }
            
            guard Airship.shared.urlAllowList.isAllowed(url, scope: .openURL) else {
                AirshipLogger.error("URL \(url) not allowed. Unable to open URL.")
                return false
            }
            
            return true
        }
    }
    
    public func perform(with arguments: ActionArguments, completionHandler: @escaping UAActionCompletionHandler) {
        guard let url = parseURL(arguments) else {
            completionHandler(ActionResult.empty())
            return
        }
        
        #if !os(watchOS)
        UIApplication.shared.open(url, options: [:]) { success in
            if success {
                completionHandler(ActionResult(value: url.absoluteString))
            } else {
                let error = AirshipErrors.error("Unable to open url \(url).")
                completionHandler(ActionResult(error: error))
            }
        }
        #else
        WKExtension.shared().openSystemURL(url)
        #endif
    }

    func parseURL(_ arguments: ActionArguments) -> URL? {
        if let string = arguments.value as? String {
            return URL(string: string)
        }
        
        return arguments.value as? URL
    }
}
