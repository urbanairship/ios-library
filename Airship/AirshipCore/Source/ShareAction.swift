/* Copyright Airship and Contributors */

/**
 * Shares text using ActivityViewController.
 * *
 * Expected argument value is a `String`.
 *
 * Valid situations: `ActionSituation.foregroundPush`, `ActionSituation.launchedFromPush`,
 * `ActionSituation.webViewInvocation`, `ActionSituation.manualInvocation`,
 * `ActionSituation.foregroundInteractiveButton`, and `ActionSituation.automation`
 */
#if os(iOS)

public final class ShareAction: AirshipAction {
    /// Default names - "share_action", "^s"
    public static let defaultNames = ["share_action", "^s"]

    /// Deafult predciate - rejects `ActionSituation.foregroundPush`
    public static let defaultPredicate: @Sendable (ActionArguments) -> Bool = { args in
        return args.situation != .foregroundPush
    }
    
    @objc
    public static let name = "share_action"

    @objc
    public static let shortName = "^s"
    
    public func accepts(arguments: ActionArguments) async -> Bool {
        guard arguments.situation != .backgroundPush,
            arguments.situation != .backgroundInteractiveButton
        else {
            return false
        }
        return true
    }

    @MainActor
    public func perform(arguments: ActionArguments) async throws -> AirshipJSON? {

        AirshipLogger.debug("Running share action: \(arguments)")

        let activityViewController = ActivityViewController(
            activityItems: [arguments.value.unWrap() as Any],
            applicationActivities: nil
        )

        activityViewController.excludedActivityTypes = [
            .assignToContact,
            .print,
            .saveToCameraRoll,
            .airDrop,
            .postToFacebook,
        ]

        let viewController = UIViewController()
        var window: UIWindow? = AirshipUtils.presentInNewWindow(
            viewController,
            windowLevel: .alert
        )

        activityViewController.dismissalBlock = {
            window?.windowLevel = .normal
            window?.isHidden = true
            window = nil
        }

        if let popoverPresentationController = activityViewController.popoverPresentationController {
            popoverPresentationController.permittedArrowDirections = []
            // Set the delegate, center the popover on the screen
            popoverPresentationController.delegate = activityViewController
            popoverPresentationController.sourceRect = activityViewController.sourceRect()
            popoverPresentationController.sourceView = viewController.view
        }

        viewController.present(
            activityViewController,
            animated: true
        )

        return nil
    }
}
#endif
