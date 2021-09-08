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
public class EnableFeatureAction : NSObject, Action {
    
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

    private let push: () -> PushProtocol
    private let location: () -> UALocationProvider?

    @objc
    public override convenience init() {
        self.init(push: { return Airship.push },
                  location: { return Airship.shared.locationProvider })
    }

    @objc
    public init(push: @escaping () -> Push,
                location: @escaping () -> UALocationProvider?) {
        self.push = push
        self.location = location
    }
    
    public func acceptsArguments(_ arguments: ActionArguments) -> Bool {
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

    public func perform(with arguments: ActionArguments, completionHandler: @escaping UAActionCompletionHandler) {
        
        switch (arguments.value as? String ?? "") {
        case EnableFeatureAction.userNotificationsActionValue:
            enableUserNotifications(completionHandler)
        case EnableFeatureAction.locationActionValue:
            enableLocation(completionHandler)
        case EnableFeatureAction.backgroundLocationActionValue:
            enableBackgroundLocation(completionHandler)
        default:
            completionHandler(ActionResult.empty())
        }
    }

    private func navigateToSystemSettings(_ completionHandler: @escaping UAActionCompletionHandler) {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url, options: [:]) { _ in
                completionHandler(ActionResult.empty())
            }
        } else {
            AirshipLogger.error("Unable to navigate to system settings.")
            completionHandler(ActionResult.empty())
        }
    }

    func enableUserNotifications(_ completionHandler: @escaping UAActionCompletionHandler) {
        Airship.shared.privacyManager.enableFeatures(.push)

        push().userPushNotificationsEnabled = true

        if (push().userPromptedForNotifications)  {
            if (push().authorizedNotificationSettings == []) {
                navigateToSystemSettings(completionHandler)
            } else {
                completionHandler(ActionResult.empty())
            }
        } else {
            completionHandler(ActionResult.empty())
        }
    }

    func enableBackgroundLocation(_ completionHandler: @escaping UAActionCompletionHandler) {
        location()?.isBackgroundLocationUpdatesAllowed = true
        enableLocation(completionHandler)
    }

    func enableLocation(_ completionHandler: @escaping UAActionCompletionHandler) {
        Airship.shared.privacyManager.enableFeatures(.location)

        if let locationProvider = location() {
            locationProvider.isLocationUpdatesEnabled = true
            if (locationProvider.isLocationDeniedOrRestricted()) {
                navigateToSystemSettings(completionHandler)
                return
            }
        }
        
        completionHandler(ActionResult.empty())
    }
}
