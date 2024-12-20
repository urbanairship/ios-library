/* Copyright Airship and Contributors */


#if canImport(UIKit)
import UIKit
#endif

/// Sets the pasteboard's string.
///
/// Expected argument values: String or an Object with the pasteboard's string
/// under the 'text' key.
///
/// Valid situations: `ActionSituation.launchedFromPush`,
/// `ActionSituation.webViewInvocation`, `ActionSituation.manualInvocation`,
/// `ActionSituation.foregroundInteractiveButton`, `ActionSituation.backgroundInteractiveButton`,
/// and `ActionSituation.automation`
///
/// Result value: The arguments value.
@available(tvOS, unavailable)
public final class PasteboardAction: AirshipAction {

    /// Default names - "clipboard_action", "^c"
    public static let defaultNames = ["clipboard_action", "^c"]

    public func accepts(arguments: ActionArguments) async -> Bool {
        switch arguments.situation {
        case .manualInvocation, .webViewInvocation, .launchedFromPush,
            .backgroundInteractiveButton, .foregroundInteractiveButton,
            .automation:
            return pasteboardString(arguments) != nil
        case .backgroundPush, .foregroundPush:
            return false
        }
    }

    public func perform(arguments: ActionArguments) async throws -> AirshipJSON? {
        #if !os(watchOS)
        UIPasteboard.general.string = pasteboardString(arguments)
        #endif
        return arguments.value
    }

    func pasteboardString(_ arguments: ActionArguments) -> String? {
        if let value = arguments.value.unWrap() as? String {
            return value
        }

        if let dict = arguments.value.unWrap() as? [AnyHashable: Any] {
            return dict["text"] as? String
        }

        return nil
    }
}
