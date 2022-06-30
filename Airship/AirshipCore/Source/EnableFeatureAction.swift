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
 * Valid situations:  UASituationLaunchedFromPush,
 * UASituationWebViewInvocation, UASituationManualInvocation,
 * UASituationForegroundInteractiveButton, and UASituationAutomation
 *
 * Default predicate: Rejects foreground pushes with visible display options.
 *
 * Result value: Empty.
 */
@objc(UAEnableFeatureAction)
public class EnableFeatureAction : NSObject, Action {

    /// Metadata key for a block that takes the permission results`(PermissionStatus, PermissionStatus) -> Void`.
    /// - Note: For internal use only. :nodoc:
    @objc
    public static let resultCompletionHandlerMetadata = PromptPermissionAction.resultReceiverMetadataKey

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

    private let permissionPrompter: () -> PermissionPrompter
    private let location: () -> UALocationProvider?

    required init(permissionPrompter: @escaping () -> PermissionPrompter,
                  location: @escaping () -> UALocationProvider?) {
        self.permissionPrompter = permissionPrompter
        self.location = location
    }

    public convenience override init() {
        self.init(
            permissionPrompter: {
                return AirshipPermissionPrompter(permissionsManager: Airship.shared.permissionsManager)
            },
            location: { return Airship.shared.locationProvider }
        )
    }
    
    public func acceptsArguments(_ arguments: ActionArguments) -> Bool {
        switch (arguments.situation) {
        case .automation: fallthrough
        case .manualInvocation: fallthrough
        case .launchedFromPush: fallthrough
        case .webViewInvocation: fallthrough
        case .foregroundPush: fallthrough
        case .foregroundInteractiveButton:
            return (try? self.parsePermission(arguments: arguments)) != nil
        case .backgroundPush: fallthrough
        case .backgroundInteractiveButton: fallthrough
        @unknown default:
            return false
        }
    }

    public func perform(with arguments: ActionArguments, completionHandler: @escaping UAActionCompletionHandler) {

        var permission: Permission!
        do {
            permission = try parsePermission(arguments: arguments)
        } catch {
            completionHandler(ActionResult(error: error))
            return
        }

        if (EnableFeatureAction.backgroundLocationActionValue == (arguments.value as? String)) {
            location()?.isBackgroundLocationUpdatesAllowed = true
        }

        self.permissionPrompter().prompt(permission: permission,
                                         enableAirshipUsage: true,
                                         fallbackSystemSettings: true) { start, end in

            if let metadata = arguments.metadata {
               let resultReceiver = metadata[PromptPermissionAction.resultReceiverMetadataKey] as? PermissionResultReceiver

                resultReceiver?(permission, start, end)
            }
        }

        completionHandler(ActionResult.empty())
    }

    private func parsePermission(arguments: ActionArguments) throws -> Permission {
        let value = arguments.value as? String ?? ""
        switch (value) {
        case EnableFeatureAction.userNotificationsActionValue:
            return .displayNotifications
        case EnableFeatureAction.locationActionValue:
            return .location
        case EnableFeatureAction.backgroundLocationActionValue:
            return .location
        default:
            throw AirshipErrors.error("Invalid argument \(value)")
        }
    }
}
