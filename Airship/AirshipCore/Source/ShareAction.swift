/* Copyright Airship and Contributors */

/**
 * Shares text using ActivityViewController.
 *
 * This action is registered under the names share_action and ^s.
 *
 * Expected argument value is an NSString.
 *
 * Valid situations: UASituationForegroundPush, UASituationLaunchedFromPush,
 * UASituationWebViewInvocation, UASituationManualInvocation,
 * UASituationForegroundInteractiveButton, and UASituationAutomation
 *
 * Default predicate: Rejects situation UASituationForegroundPush.
 *
 * Result value: nil
 *
 */
#if os(iOS)
@objc(UAShareAction)

public class ShareAction: NSObject, Action {

    @objc
    public static let name = "share_action"

    @objc
    public static let shortName = "^s"


    public func acceptsArguments(_ arguments: ActionArguments) -> Bool {
        guard arguments.situation != .backgroundPush,
            arguments.situation != .backgroundInteractiveButton,
            arguments.value as? String != nil
        else {
            return false
        }
        return true
    }

    public func perform(
        with arguments: ActionArguments,
        completionHandler: UAActionCompletionHandler
    ) {
        AirshipLogger.debug("Running share action: \(arguments)")

        let activityViewController = ActivityViewController(
            activityItems: [arguments.value as Any],
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
        var window: UIWindow? = Utils.presentInNewWindow(
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

        completionHandler(ActionResult.empty())
    }
}
#endif
