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
@available(tvOS, unavailable)
@objc(UAShareAction)
public class ShareAction : NSObject, UAAction {
    
    @objc
    public static let name = "share_action"
    
    @objc
    public static let shortName = "^s"

    private var lastActivityViewController: ActivityViewController?

    public func acceptsArguments(_ arguments: UAActionArguments) -> Bool {
        guard arguments.situation != .backgroundPush,
              arguments.situation != .backgroundInteractiveButton,
              arguments.value as? String != nil else{
            return false
        }
        return true
    }

    public func perform(with arguments: UAActionArguments, completionHandler: UAActionCompletionHandler) {
        AirshipLogger.debug("Running share action: \(arguments)")

        let activityItems = [arguments.value as Any]

        let activityViewController = ActivityViewController(activityItems: activityItems , applicationActivities: nil)
        activityViewController.excludedActivityTypes = [
            .assignToContact,
            .print,
            .saveToCameraRoll,
            .airDrop,
            .postToFacebook
        ]

        let displayShareBlock: (() -> Void) = { [self] in
            lastActivityViewController = activityViewController
            if let popoverPresentationController = activityViewController.popoverPresentationController {
                popoverPresentationController.permittedArrowDirections = []
                
                // Set the delegate, center the popover on the screen
                popoverPresentationController.delegate = activityViewController
                popoverPresentationController.sourceRect = activityViewController.sourceRect()
                popoverPresentationController.sourceView = UAUtils.topController()?.view

                UAUtils.topController()?.present(activityViewController, animated: true)
            } else {
                UAUtils.topController()?.present(activityViewController, animated: true)
            }
        }


        activityViewController.dismissalBlock = { [weak self] in
            self?.lastActivityViewController = nil
        }
        
        
        if (self.lastActivityViewController != nil) {
            let dismissalBlock = self.lastActivityViewController?.dismissalBlock
            self.lastActivityViewController?.dismissalBlock = {
                dismissalBlock?()
                displayShareBlock()
            }
        } else {
            displayShareBlock()
        }
        
        completionHandler(UAActionResult.empty())
    }
}
