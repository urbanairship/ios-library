/* Copyright Airship and Contributors */

import Foundation

/// Action that prompts for permission using `PermissionsManager`
///
/// Expected arguments, dictionary with keys:
/// -`enable_airship_usage`: Bool?. If related airship features should be enabled if the permission is granted.
/// -`fallback_system_settings`: Bool?. If denied, fallback to system settings.
/// -`permission`: String. The name of the permission. `post_notifications`, `bluetooth`, `mic`, `location`, `contacts`, `camera`, etc...
///
/// Accepted situations: autmoation, manualInvocation, webViewInvocation, launchedFromPush, foregroundInteractiveButton, foreground Push
///
@objc(UAPromptPermissionAction)
public class PromptPermissionAction: NSObject, Action {

    /// Metadata key for the reuslt receiver. Must be (Permission, PermissionStatus, PermissionStatus) -> Void
    /// - Note: For internal use only. :nodoc:
    @objc
    public static let resultReceiverMetadataKey = "permission_result"

    private let permissionPrompter: () -> PermissionPrompter

    required init(permissionPrompter: @escaping () -> PermissionPrompter) {
        self.permissionPrompter = permissionPrompter
    }

    convenience override init() {
        self.init {
            return AirshipPermissionPrompter(permissionsManager: Airship.shared.permissionsManager)
        }
    }

    public func acceptsArguments(_ arguments: ActionArguments) -> Bool {
        switch (arguments.situation) {
        case .automation: fallthrough
        case .manualInvocation: fallthrough
        case .launchedFromPush: fallthrough
        case .webViewInvocation: fallthrough
        case .foregroundInteractiveButton: fallthrough
        case .foregroundPush:
            return arguments.value != nil
        case .backgroundPush: fallthrough
        case .backgroundInteractiveButton: fallthrough
        @unknown default:
            return false
        }
    }

    public func perform(with arguments: ActionArguments,
                 completionHandler: @escaping UAActionCompletionHandler) {

        guard let arg = arguments.value else {
            completionHandler(ActionResult.empty())
            return
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: arg, options: [])
            let args = try JSONDecoder().decode(Args.self, from: data)
            self.permissionPrompter()
                .prompt(permission: args.permission,
                        enableAirshipUsage: args.enableAirshipUsage ?? false,
                        fallbackSystemSettings: args.fallbackSystemSettings ?? false) { start, end in

                    if let metadata = arguments.metadata {
                        let resultReceiver = metadata[PromptPermissionAction.resultReceiverMetadataKey] as? PermissionResultReceiver

                        resultReceiver?(args.permission, start, end)
                    }
                }
            completionHandler(ActionResult.empty())
        }
        catch {
            completionHandler(ActionResult(error: error))
            return
        }
    }

    internal struct Args: Decodable {
        let enableAirshipUsage: Bool?
        let fallbackSystemSettings: Bool?
        let permission: Permission

        enum CodingKeys: String, CodingKey {
            case enableAirshipUsage = "enable_airship_usage"
            case fallbackSystemSettings = "fallback_system_settings"
            case permission = "permission"
        }
    }
}
