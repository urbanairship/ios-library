/* Copyright Airship and Contributors */

import Foundation

/// Action that prompts for permission using `PermissionsManager`
///
/// Expected arguments, dictionary with keys:
/// -`enable_airship_usage`: Bool?. If related airship features should be enabled if the permission is granted.
/// -`fallback_system_settings`: Bool?. If denied, fallback to system settings.
/// -`permission`: String. The name of the permission. `post_notifications`, `bluetooth`, `mic`, `location`, `contacts`, `camera`, etc...
///
/// Valid situations: `ActionSituation.foregroundPush`, `ActionSituation.launchedFromPush`,
/// `ActionSituation.webViewInvocation`, `ActionSituation.manualInvocation`,
/// `ActionSituation.foregroundInteractiveButton`, and `ActionSituation.automation`
public final class PromptPermissionAction: AirshipAction {

    /// Default names - "prompt_permission_action", "^pp"
    public static let defaultNames = ["prompt_permission_action", "^pp"]
    
    /// Default predicate - rejects foreground pushes with visible display options
    public static let defaultPredicate: @Sendable (ActionArguments) -> Bool = { args in
        return args.metadata[ActionArguments.isForegroundPresentationMetadataKey] as? Bool != true
    }

    /// Metadata key for the result receiver. Must be (Permission, PermissionStatus, PermissionStatus) -> Void
    /// - Note: For internal use only. :nodoc:
    public static let resultReceiverMetadataKey = "permission_result"

    private let permissionPrompter: @Sendable () -> PermissionPrompter

    public convenience init() {
           self.init {
               return AirshipPermissionPrompter(
                   permissionsManager: Airship.permissionsManager
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
            .foregroundInteractiveButton, .foregroundPush:
            return true
        case .backgroundPush: fallthrough
        case .backgroundInteractiveButton: fallthrough
        @unknown default:
            return false
        }
    }

    public func perform(arguments: ActionArguments) async throws -> AirshipJSON? {
            
        let unwrapped = arguments.value.unWrap()
        guard let arg = unwrapped else {
            return nil
        }
                       
        let data = try JSONSerialization.data(
            withJSONObject: arg,
            options: []
        )
        let args = try JSONDecoder().decode(Args.self, from: data)
                
        let (start, end) = await self.permissionPrompter()
            .prompt(
                permission: args.permission,
                enableAirshipUsage: args.enableAirshipUsage ?? false,
                fallbackSystemSettings: args.fallbackSystemSettings ?? false
            )

        let resultReceiver = arguments.metadata[
            PromptPermissionAction.resultReceiverMetadataKey
        ] as? PermissionResultReceiver

        await resultReceiver?(args.permission, start, end)

        return nil
    }

    internal struct Args: Decodable {
        let enableAirshipUsage: Bool?
        let fallbackSystemSettings: Bool?
        let permission: AirshipPermission

        enum CodingKeys: String, CodingKey {
            case enableAirshipUsage = "enable_airship_usage"
            case fallbackSystemSettings = "fallback_system_settings"
            case permission = "permission"
        }
    }
}


