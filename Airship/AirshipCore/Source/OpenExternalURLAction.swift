/* Copyright Airship and Contributors */

/// Opens a URL, either in safari or using custom URL schemes.
///
/// Expected argument values: A valid URL String.
///
/// Valid situations: `ActionSituation.foregroundPush`, `ActionSituation.launchedFromPush`
/// `ActionSituation.webViewInvocation`, `ActionSituation.foregroundInteractiveButton`,
/// `ActionSituation.manualInvocation`, and `ActionSituation.automation`
///
/// Result value: The input value.
public final class OpenExternalURLAction: AirshipAction {

    /// Default names - "open_external_url_action", "^u", "^w", "wallet_action"
    public static let defaultNames = ["open_external_url_action", "^u", "^w", "wallet_action"]

    /// Default predicate - rejects `ActionSituation.foregroundPush`
    public static let defaultPredicate: @Sendable (ActionArguments) -> Bool = { args in
        return args.situation != .foregroundPush
    }

    private let urlOpener: any URLOpenerProtocol

    init(urlOpener: any URLOpenerProtocol) {
        self.urlOpener = urlOpener
    }

    public convenience init() {
        self.init(urlOpener: DefaultURLOpener())
    }

    public func accepts(arguments: ActionArguments) async -> Bool {
        switch arguments.situation {
        case .backgroundPush:
            return false
        case .backgroundInteractiveButton:
            return false
        default:
            return true
        }
    }

    @MainActor
    public func perform(arguments: ActionArguments) async throws -> AirshipJSON? {
        let url = try parseURL(arguments.value)

        guard Airship.urlAllowList.isAllowed(url, scope: .openURL) else {
            throw AirshipErrors.error("URL \(url) not allowed")
        }

        guard await urlOpener.openURL(url) else {
            throw AirshipErrors.error("Unable to open url \(arguments.value).")
        }

        return arguments.value
    }
    
    private func parseURL(_ value: AirshipJSON) throws -> URL {
        if let value = value.unWrap() as? String {
            if let url = AirshipUtils.parseURL(value) {
                return url
            }
        }

        throw AirshipErrors.error("Invalid URL: \(value)")
    }
}




