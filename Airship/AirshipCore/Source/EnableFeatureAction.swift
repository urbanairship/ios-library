/* Copyright Airship and Contributors */
@_spi(AirshipInternal) import AirshipBasement

/// Enables an Airship feature.
///
/// Expected argument values:
/// - "user_notifications": To enable user notifications.
/// - "location": To enable location updates.
/// - "background_location": To enable location and allow background updates.
/// - Any `AirshipPermission` raw value, e.g. "camera" or "photo_library".
///
/// Only `.displayNotifications` has a built-in delegate. Prompting for any other permission
/// requires the app to register an `AirshipPermissionDelegate` with `PermissionsManager`,
/// otherwise the prompt resolves to `.notDetermined` and nothing is shown.
///
/// Valid situations:  `ActionSituation.launchedFromPush`,
/// `ActionSituation.webViewInvocation`, `ActionSituation.manualInvocation`,
/// `ActionSituation.foregroundInteractiveButton`, and `ActionSituation.automation`
public final class EnableFeatureAction: AirshipAction {
    /// Default names - "enable_feature", "^ef"
    public static let defaultNames: [String] = ["enable_feature", "^ef"]
    
    /// Default predicate - rejects foreground pushes with visible display options
    public static let defaultPredicate: @Sendable (ActionArguments) -> Bool = { args in
        return args.metadata[ActionArguments.isForegroundPresentationMetadataKey] as? Bool != true
    }

    /// Metadata key for a block that takes the permission results`(PermissionStatus, PermissionStatus) -> Void`.
    /// - Note: For internal use only. :nodoc:
    public static let resultReceiverMetadataKey: String = PromptPermissionAction
        .resultReceiverMetadataKey

    public static let userNotificationsActionValue: String = "user_notifications"
    public static let locationActionValue: String = "location"
    public static let backgroundLocationActionValue: String = "background_location"

    private let permissionPrompter: @Sendable () -> any PermissionPrompter


    public convenience init() {
           self.init {
               return AirshipPermissionPrompter(
                   permissionsManager: Airship.permissionsManager
               )
           }
       }
    
    required init(permissionPrompter: @escaping @Sendable () -> any PermissionPrompter) {
        self.permissionPrompter = permissionPrompter
    }
    
    public func accepts(arguments: ActionArguments) async -> Bool {
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
    public func perform(arguments: ActionArguments) async throws -> AirshipJSON? {
        let permission = try parsePermission(arguments: arguments)

        let result = await self.permissionPrompter()
            .prompt(
                permission: permission,
                enableAirshipUsage: true,
                fallbackSystemSettings: true
            )

        let resultReceiver = arguments.metadata[
            EnableFeatureAction.resultReceiverMetadataKey
        ] as? PermissionResultReceiver

        await resultReceiver?(permission, result.startStatus, result.endStatus)

        return nil
    }

    private func parsePermission(
        arguments: ActionArguments
    ) throws -> AirshipPermission {
        let unwrapped = arguments.value.unWrap()
        let value = unwrapped as? String ?? ""
        switch value {
        case EnableFeatureAction.userNotificationsActionValue:
            return .displayNotifications
        case EnableFeatureAction.locationActionValue:
            return .location
        case EnableFeatureAction.backgroundLocationActionValue:
            return .location
        default:
            // Permissions added after these three are named by their AirshipPermission
            // raw value, so no per-permission argument constant is needed.
            guard let permission = AirshipPermission(rawValue: value) else {
                throw AirshipErrors.error("Invalid argument \(value)")
            }
            return permission
        }
    }
}
