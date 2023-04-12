/* Copyright Airship and Contributors */

/// Enables an Airship feature.
///
/// This action is registered under the names enable_feature and ^ef.
///
/// Expected argument values:
/// - "user_notifications": To enable user notifications.
/// - "location": To enable location updates.
/// - "background_location": To enable location and allow background updates.
///
/// Valid situations:  UASituationLaunchedFromPush,
/// UASituationWebViewInvocation, UASituationManualInvocation,
/// UASituationForegroundInteractiveButton, and UASituationAutomation
///
/// Default predicate: Rejects foreground pushes with visible display options.
///
/// Result value: Empty.
@objc(UAEnableFeatureAction)
public class EnableFeatureAction: NSObject, Action {

    /// Metadata key for a block that takes the permission results`(PermissionStatus, PermissionStatus) -> Void`.
    /// - Note: For internal use only. :nodoc:
    @objc
    public static let resultCompletionHandlerMetadata = PromptPermissionAction
        .resultReceiverMetadataKey

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

    required init(permissionPrompter: @escaping () -> PermissionPrompter) {
        self.permissionPrompter = permissionPrompter
    }

    public convenience override init() {
        self.init {
            return AirshipPermissionPrompter(
                permissionsManager: Airship.shared.permissionsManager
            )
        }
    }

    public func acceptsArguments(_ arguments: ActionArguments) -> Bool {
        switch arguments.situation {
        case .automation, .manualInvocation, .launchedFromPush,
            .webViewInvocation,
            .foregroundPush, .foregroundInteractiveButton:
            return (try? self.parsePermission(arguments: arguments)) != nil
        case .backgroundPush: fallthrough
        case .backgroundInteractiveButton: fallthrough
        @unknown default:
            return false
        }
    }

    @MainActor
    public func perform(
        with arguments: ActionArguments
    ) async -> ActionResult {

            var permission: AirshipPermission!
            do {
                permission = try parsePermission(arguments: arguments)
            } catch {
                return ActionResult(error: error)
            }
            
            let (start, end) = await self.permissionPrompter()
                .prompt(
                    permission: permission,
                    enableAirshipUsage: true,
                    fallbackSystemSettings: true
                )
            
            if let metadata = arguments.metadata {
                let resultReceiver =
                metadata[
                    PromptPermissionAction.resultReceiverMetadataKey
                ]
                as? PermissionResultReceiver
                
                resultReceiver?(permission, start, end)
            }
            return ActionResult.empty()
    }

    private func parsePermission(arguments: ActionArguments) throws
        -> AirshipPermission
    {
        let value = arguments.value as? String ?? ""
        switch value {
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
