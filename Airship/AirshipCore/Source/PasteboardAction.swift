/* Copyright Airship and Contributors */

#if !os(watchOS)

import Foundation

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
    public static let defaultNames: [String] = ["clipboard_action", "^c"]

    private let pasteboard: any AirshipPasteboardProtocol

    init(pasteboard: any AirshipPasteboardProtocol = DefaultAirshipPasteboard()) {
        self.pasteboard = pasteboard
    }

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

    @MainActor
    public func perform(arguments: ActionArguments) async throws -> AirshipJSON? {
        if let string = pasteboardString(arguments) {
            self.pasteboard.copy(value: string)
        }

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

#endif
