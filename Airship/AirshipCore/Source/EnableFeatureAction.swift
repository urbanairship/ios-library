/* Copyright Airship and Contributors */

/**
 * Enables an Airship feature.
 *
 * This action is registered under the names enable_feature and ^ef.
 *
 * Expected argument values:
 * - "user_notifications": To enable user notifications.
 * - "location": To enable location updates.
 * - "background_location": To enable location and allow background updates.
 *
 * Valid situations: UASituationForegroundPush, UASituationLaunchedFromPush,
 * UASituationWebViewInvocation, UASituationManualInvocation,
 * UASituationForegroundInteractiveButton, and UASituationAutomation
 *
 * Default predicate: Rejects foreground pushes with visible display options.
 *
 * Result value: Empty.
 */
@objc(UAEnableFeatureAction)
public class EnableFeatureAction : NSObject, UAAction {
    
    @objc
    public static let name = "enable_feature"
    
    @objc
    public static let shortName = "^ef"

    @objc
    public static let userNotificationsActionValue = "user_notifications"
    
    @objc
    public static let locationActionValue = "location"
    
    @objc
    public static let backgroundLocationActionValue = "background_location"
    
    public func acceptsArguments(_ arguments: UAActionArguments) -> Bool {
        guard arguments.situation != .backgroundPush,
              arguments.situation != .backgroundInteractiveButton else {
            return false
        }

        let validValues = [
            EnableFeatureAction.userNotificationsActionValue,
            EnableFeatureAction.locationActionValue,
            EnableFeatureAction.backgroundLocationActionValue
        ]
        
        guard let value = arguments.value as? String,
              validValues.contains(value) else {
            return false
        }
        
        return true
    }

    public func perform(with arguments: UAActionArguments, completionHandler: @escaping UAActionCompletionHandler) {
        
        switch (arguments.value as? String ?? "") {
        case EnableFeatureAction.userNotificationsActionValue:
            enableUserNotifications(completionHandler)
        case EnableFeatureAction.locationActionValue:
            enableLocation(completionHandler)
        case EnableFeatureAction.backgroundLocationActionValue:
            enableBackgroundLocation(completionHandler)
        default:
            completionHandler(UAActionResult.empty())
        }
    }

    private func navigateToSystemSettings(_ completionHandler: @escaping UAActionCompletionHandler) {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url, options: [:]) { _ in
                completionHandler(UAActionResult.empty())
            }
        } else {
            AirshipLogger.error("Unable to navigate to system settings.")
            completionHandler(UAActionResult.empty())
        }
    }

    func enableUserNotifications(_ completionHandler: @escaping UAActionCompletionHandler) {
        UAirship.shared().privacyManager.enableFeatures(.push)
        
        let push = UAirship.push()!
        push.userPushNotificationsEnabled = true

        if (push.userPromptedForNotifications)  {
            if (push.authorizedNotificationSettings == []) {
                navigateToSystemSettings(completionHandler)
            } else {
                completionHandler(UAActionResult.empty())
            }
        } else {
            completionHandler(UAActionResult.empty())
        }
    }

    func enableBackgroundLocation(_ completionHandler: @escaping UAActionCompletionHandler) {
        UAirship.shared().locationProvider?.isBackgroundLocationUpdatesAllowed = true
        enableLocation(completionHandler)
    }

    func enableLocation(_ completionHandler: @escaping UAActionCompletionHandler) {
        UAirship.shared().privacyManager.enableFeatures(.location)

        if let locationProvider = UAirship.shared().locationProvider {
            locationProvider.isLocationUpdatesEnabled = true
            if (locationProvider.isLocationDeniedOrRestricted()) {
                navigateToSystemSettings(completionHandler)
                return
            }
        }
        
        completionHandler(UAActionResult.empty())
    }
}
