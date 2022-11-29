/* Copyright Airship and Contributors */

#if !os(tvOS) && !os(watchOS)

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
/// Valid situations: UASituationForegroundPush, UASituationLaunchedFromPush, UASituationWebViewInvocation
/// UASituationManualInvocation, UASituationForegroundInteractiveButton, and UASituationAutomation
///
/// Result value: nil
@objc(UARateAppAction)
public class RateAppAction: NSObject, Action {

    static let actionName = "rate_app_action"
    static let actionShortName = "^ra"

    let itunesID: () -> String?
    let appRater: AppRaterProtocol

    init(
        appRater: AppRaterProtocol,
        itunesID: @escaping () -> String?
    ) {
        self.appRater = appRater
        self.itunesID = itunesID
    }

    @objc
    public convenience override init() {
        self.init(appRater: DefaultAppRater()) {
            return Airship.shared.config.itunesID
        }
    }

    public func acceptsArguments(_ arguments: ActionArguments) -> Bool {
        switch arguments.situation {
        case .manualInvocation, .launchedFromPush, .foregroundPush,
            .webViewInvocation, .foregroundInteractiveButton, .automation:
            return true
        case .backgroundPush: fallthrough
        case .backgroundInteractiveButton: fallthrough
        @unknown default: return false
        }
    }

    public func perform(with arguments: ActionArguments) async
        -> ActionResult
    {
        do {
            let args = try Args.from(actionArguments: arguments)
            if args.showPrompt == true {
                try await appRater.showPrompt()
            } else {
                guard let itunesID = args.itunesID ?? self.itunesID() else {
                    throw AirshipErrors.error("Missing itunes ID")
                }
                try await appRater.openStore(itunesID: itunesID)
            }
            return ActionResult.empty()
        } catch {
            return ActionResult(error: error)
        }
    }

    private struct Args: Decodable {
        let itunesID: String?
        let showPrompt: Bool?

        static func from(actionArguments: ActionArguments) throws -> Args {
            guard let value = actionArguments.value else {
                return Args(itunesID: nil, showPrompt: nil)
            }

            guard let value = value as? [String: Any],
                let data = try? JSONSerialization.data(
                    withJSONObject: value,
                    options: []
                ),
                let args = try? JSONDecoder().decode(Args.self, from: data)
            else {
                throw AirshipErrors.error("Failed to parse args \(value)")
            }

            return args
        }

        enum CodingKeys: String, CodingKey {
            case itunesID = "itunes_id"
            case showPrompt = "show_link_prompt"
        }
    }
}

protocol AppRaterProtocol {
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
        SKStoreReviewController.requestReview(in: scene)
    }

    private func findScene() -> UIWindowScene? {
        if let mainWindowScene = Utils.mainWindow()?.windowScene {
            return mainWindowScene
        }

        return try? Utils.findWindowScene()
    }
}

/// Default predicate for the rate app action. Rejects foreground push.
@objc(UARateAppActionPredicate)
public class RateAppActionPredicate: NSObject, ActionPredicateProtocol {
    public func apply(_ args: ActionArguments) -> Bool {
        return args.situation != .foregroundPush
    }
}

#endif
