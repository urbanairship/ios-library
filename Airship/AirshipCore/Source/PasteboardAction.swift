/* Copyright Airship and Contributors */

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
 */
@available(tvOS, unavailable)
@objc(UAPasteboardAction)
public class PasteboardAction : NSObject, Action {
    
    @objc
    public static let name = "clipboard_action"

    @objc
    public static let shortname = "^c"
    
    public func acceptsArguments(_ arguments: ActionArguments) -> Bool {
        
        switch arguments.situation {
        case .manualInvocation, .webViewInvocation, .launchedFromPush, .backgroundInteractiveButton, .foregroundInteractiveButton, .automation:
            return pasteboardString(arguments) != nil
        case .backgroundPush, .foregroundPush:
            return false
        default:
            return false
        }
    }

    public func perform(with arguments: ActionArguments, completionHandler: UAActionCompletionHandler) {
        #if !os(watchOS)
        UIPasteboard.general.string = pasteboardString(arguments)
        #endif
        completionHandler(ActionResult(value: arguments.value))
    }

    func pasteboardString(_ arguments: ActionArguments) -> String? {
        if let value = arguments.value as? String {
            return value
        }

        if let dict = arguments.value as? [AnyHashable : Any] {
            return dict["text"] as? String
        }
        
        return nil
    }
}
