/* Copyright Airship and Contributors */

/// Opens a deep link URL.
///
/// Expected argument values: A valid URL String.
///
/// Valid situations: All but `backgroundPush` and `backgroundInteractiveButton`
public final class DeepLinkAction: AirshipAction {

    /// Default names - "deep_link_action", "^d"
    public static let defaultNames = ["deep_link_action", "^d"]

    /// Default predicate - Rejects `Airship.foregroundPush`
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
        let result = await Airship.shared.deepLink(url)

        if !result {
            try await self.openURL(url)
        }

        return nil
    }

    @MainActor
    private func openURL(_ url: URL) async throws {
        guard Airship.urlAllowList.isAllowed(url, scope: .openURL) else {
            throw AirshipErrors.error("URL \(url) not allowed")
        }

        guard await urlOpener.openURL(url) else {
            throw AirshipErrors.error("Unable to open URL \(url).")
        }
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
