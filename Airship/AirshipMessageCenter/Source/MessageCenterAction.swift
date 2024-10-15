/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
public import AirshipCore
#endif

/// Message center action that launches the message center.
///
///
/// Valid situations: `ActionSituation.manualInvocation`, `ActionSituation.launchedFromPush`
/// `ActionSituation.webViewInvocation`, `ActionSituation.foregroundInteractiveButton`,
/// `ActionSituation.manualInvocation`, and `ActionSituation.automation`
///
public final class MessageCenterAction: AirshipAction {

    /// Default names - "_uamid", "overlay_inbox_action", "display_inbox_action", "^mc", "^mco"
    public static let defaultNames = ["_uamid", "overlay_inbox_action", "display_inbox_action", "^mc", "^mco"]

    /// Action value for the message ID place holder.
    public static let messageIDPlaceHolder = "auto"

    public func accepts(arguments: ActionArguments) async -> Bool {
        switch arguments.situation {
        case .manualInvocation, .launchedFromPush, .webViewInvocation,
            .automation,
            .foregroundInteractiveButton:
            return true
        case .backgroundInteractiveButton: fallthrough
        case .foregroundPush: fallthrough
        case .backgroundPush: fallthrough
        @unknown default: return false
        }
    }

    private func parseMessageID(arguments: ActionArguments) -> String? {
        if let value = arguments.value.unWrap() as? String {
            guard value == MessageCenterAction.messageIDPlaceHolder else {
                return value
            }
            if let messageID =
                arguments.metadata[ActionArguments.inboxMessageIDMetadataKey]
                as? String
            {
                return messageID
            } else if let payload =
                        (arguments.metadata[ActionArguments.pushPayloadJSONMetadataKey] as? AirshipJSON)?.unWrap()
                as? [AnyHashable: Any]
            {
                return MessageCenterMessage.parseMessageID(userInfo: payload)
            } else {
                return nil
            }

        } else if let value = arguments.value.unWrap() as? [String] {
            return value.first
        } else {
            return nil
        }
    }

    @MainActor
    public func perform(arguments: ActionArguments) async throws -> AirshipJSON? {
        if let messageID = parseMessageID(arguments: arguments),
            !messageID.isEmpty
        {
            MessageCenter.shared.display(messageID: messageID)
        } else {
            MessageCenter.shared.display()
        }

        return nil
    }
}
