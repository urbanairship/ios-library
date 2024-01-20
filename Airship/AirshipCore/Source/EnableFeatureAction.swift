/* Copyright Airship and Contributors */

/// Enables an Airship feature.
///
/// Expected argument values:
/// - "user_notifications": To enable user notifications.
/// - "location": To enable location updates.
/// - "background_location": To enable location and allow background updates.
///
/// Valid situations:  `ActionSituation.launchedFromPush`,
/// `ActionSituation.webViewInvocation`, `ActionSituation.manualInvocation`,
/// `ActionSituation.foregroundInteractiveButton`, and `ActionSituation.automation`
public final class EnableFeatureAction: AirshipAction {
    /// Default names - "enable_feature", "^ef"
    public static let defaultNames = ["enable_feature", "^ef"]
    
    /// Default predicate - rejects foreground pushes with visible display options
    public static let defaultPredicate: @Sendable (ActionArguments) -> Bool = { args in
        return args.metadata[ActionArguments.isForegroundPresentationMetadataKey] as? Bool != true
    }

    /// Metadata key for a block that takes the permission results`(PermissionStatus, PermissionStatus) -> Void`.
    /// - Note: For internal use only. :nodoc:
    public static let resultReceiverMetadataKey = PromptPermissionAction
        .resultReceiverMetadataKey

    public static let userNotificationsActionValue = "user_notifications"
    public static let locationActionValue = "location"
    public static let backgroundLocationActionValue = "background_location"

    private let permissionPrompter: @Sendable () -> PermissionPrompter


    public convenience init() {
           self.init {
               return AirshipPermissionPrompter(
                   permissionsManager: Airship.shared.permissionsManager
               )
           }
       }
    
    required init(permissionPrompter: @escaping @Sendable () -> PermissionPrompter) {
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

        let (start, end) = await self.permissionPrompter()
            .prompt(
                permission: permission,
                enableAirshipUsage: true,
                fallbackSystemSettings: true
            )

        let resultReceiver = arguments.metadata[
            EnableFeatureAction.resultReceiverMetadataKey
        ] as? PermissionResultReceiver

        await resultReceiver?(permission, start, end)

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
            throw AirshipErrors.error("Invalid argument \(value)")
        }
    }
}
