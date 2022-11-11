/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
    import AirshipCore
#endif

@objc(UAMessageCenterAction)
public class MessageCenterAction: NSObject, Action {
    public static let messageIDPlaceHolder = "auto"

    public func acceptsArguments(_ arguments: ActionArguments) -> Bool {
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
        if let value = arguments.value as? String {
            guard value == MessageCenterAction.messageIDPlaceHolder else {
                return value
            }
            if let messageID =
                arguments.metadata?[UAActionMetadataInboxMessageIDKey]
                as? String
            {
                return messageID
            } else if let payload =
                arguments.metadata?[UAActionMetadataPushPayloadKey]
                as? [AnyHashable: Any]
            {
                return MessageCenterMessage.parseMessageID(userInfo: payload)
            } else {
                return nil
            }

        } else if let value = arguments.value as? [String] {
            return value.first
        } else {
            return nil
        }
    }

    @MainActor
    public func perform(with arguments: ActionArguments) async -> ActionResult {
        if let messageID = parseMessageID(arguments: arguments),
            !messageID.isEmpty
        {
            MessageCenter.shared.display(withMessageID: messageID)
        } else {
            MessageCenter.shared.display()
        }

        return .empty()
    }
}
