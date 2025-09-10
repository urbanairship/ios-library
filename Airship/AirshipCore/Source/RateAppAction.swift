/* Copyright Airship and Contributors */

#if !os(tvOS) && !os(watchOS) && !os(macOS)

import Foundation
import StoreKit

/// Links directly to app store review page or opens an app rating prompt.
///
/// This action is registered under the names rate_app_action and ^ra.
///
/// The rate app action requires your application to provide an itunes ID as an argument value, or have it
/// set on the Airship Config `Config.itunesID` instance used for takeoff.
///
/// Expected argument values:
/// - ``show_link_prompt``: Optional Boolean, true to show prompt, false to link to the app store.
/// - ``itunes_id``: Optional String, the iTunes ID for the application to be rated.
///
/// Valid situations: `ActionSituation.foregroundPush`, `ActionSituation.launchedFromPush`, `ActionSituation.webViewInvocation`
/// `ActionSituation.manualInvocation`, `ActionSituation.foregroundInteractiveButton`, and `ActionSituation.automation`
///
/// Result value: nil
public final class RateAppAction: AirshipAction, Sendable {
    public static let defaultNames: [String] = ["rate_app_action", "^ra"]
    public static let defaultPredicate: @Sendable (ActionArguments) -> Bool = { args in
        return args.situation != .foregroundPush
    }

    let itunesID: @Sendable () -> String?
    let appRater: any AppRaterProtocol

    init(
        appRater: any AppRaterProtocol,
        itunesID: @escaping @Sendable () -> String?
    ) {
        self.appRater = appRater
        self.itunesID = itunesID
    }

    public convenience init() {
        self.init(appRater: DefaultAppRater()) {
            return Airship.config.airshipConfig.itunesID
        }
    }

    public func accepts(arguments: ActionArguments) async -> Bool {
        switch arguments.situation {
        case .manualInvocation, .launchedFromPush, .foregroundPush,
            .webViewInvocation, .foregroundInteractiveButton, .automation:
            return true
        case .backgroundPush: fallthrough
        case .backgroundInteractiveButton: fallthrough
        @unknown default: return false
        }
    }

    public func perform(arguments: ActionArguments) async throws -> AirshipJSON? {
        var args: Args? = nil
        if !arguments.value.isNull {
            args = try arguments.value.decode()
        }

        if args?.showPrompt == true {
            try await appRater.showPrompt()
        } else {
            guard let itunesID = args?.itunesID ?? self.itunesID() else {
                throw AirshipErrors.error("Missing itunes ID")
            }
            try await appRater.openStore(itunesID: itunesID)
        }
        return nil
    }

    private struct Args: Decodable {
        let itunesID: String?
        let showPrompt: Bool?

        enum CodingKeys: String, CodingKey {
            case itunesID = "itunes_id"
            case showPrompt = "show_link_prompt"
        }
    }
}

protocol AppRaterProtocol: Sendable {
    func openStore(itunesID: String) async throws
    func showPrompt() async throws
}

private struct DefaultAppRater: AppRaterProtocol {
    @MainActor
    func openStore(itunesID: String) async throws {
        let urlString =
        "itms-apps://itunes.apple.com/app/id\(itunesID)?action=write-review"
        
        guard let url = URL(string: urlString) else {
            throw AirshipErrors.error("Unable to generate URL")
        }
        
        guard await UIApplication.shared.open(url) else {
            throw AirshipErrors.error("Failed to open url \(url)")
        }
    }
    
    @MainActor
    func showPrompt() async throws {
        guard let scene = self.findScene() else {
            throw AirshipErrors.error(
                "Unable to find scene for rate app prompt"
            )
        }
        
        AppStore.requestReview(in: scene)
    }
    
    @MainActor
    private func findScene() -> UIWindowScene? {
        return try? AirshipSceneManager.shared.lastActiveScene
    }
}

#endif
