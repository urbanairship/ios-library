/* Copyright Airship and Contributors */

import Foundation

/// An action that adds a custom event.
///
/// Expected argument values: A dictionary of keys for the custom event. When a
/// custom event action is triggered from a Message Center Rich Push Message,
/// the interaction type and ID will automatically be filled for the message if
/// they are left blank.
///
/// Valid situations: All.
///
/// Result value: nil
public final class AddCustomEventAction: AirshipAction {
    private static let eventNameKey = "name"
    private static let eventValue = "value"

    /// Default names - "add_custom_event_action"
    public static let defaultNames = ["add_custom_event_action", "^+ce"]
    
    /// Default predicate - rejects foreground pushes with visible display options and `ActionSituation.backgroundPush`
    public static let defaultPredicate: @Sendable (ActionArguments) -> Bool = { args in
        if (args.situation == .backgroundPush) {
            return false
        }
        return args.metadata[ActionArguments.isForegroundPresentationMetadataKey] as? Bool != true
    }

    /// Metadata key for in-app context.
    /// - Note: For internal use only. :nodoc:
    public static let _inAppMetadata = "in_app_metadata"

    public func accepts(arguments: ActionArguments) async -> Bool {
        return true
    }

    public func perform(arguments: ActionArguments) async throws -> AirshipJSON? {
        guard
            let dict = arguments.value.unWrap() as? [AnyHashable: Any],
            let eventName = getEventName(dict)
        else {
            throw AirshipErrors
                .error("Invalid custom event argument: \(arguments.value)")
        }

        let eventValue = getEventValue(dict)
        let interactionID = parseString(
            dict,
            key: CustomEvent.eventInteractionIDKey
        )
        let interactionType = parseString(
            dict,
            key: CustomEvent.eventInteractionTypeKey
        )
        let transactionID = parseString(
            dict,
            key: CustomEvent.eventTransactionIDKey
        )
        let properties = dict[CustomEvent.eventPropertiesKey] as? [String: Any]

        var event = CustomEvent(name: eventName, value: eventValue ?? 1.0)

        if let inApp = arguments.metadata[Self._inAppMetadata] {
            do {
                event.inApp = try AirshipJSON.wrap(inApp)
            } catch {
                AirshipLogger.error("Failed to encode in-app info for custom event: \(inApp), error: \(error)")
            }
        }

        event.transactionID = transactionID
        if let properties {
            try event.setProperties(properties)
        }

        if interactionID != nil || interactionType != nil {
            event.interactionType = interactionType
            event.interactionID = interactionID
        } else if let messageID =
                    arguments.metadata[ActionArguments.inboxMessageIDMetadataKey] as? String
        {
            event.setInteractionFromMessageCenterMessage(messageID)
        }

        if
            let json = arguments.metadata[ActionArguments.pushPayloadJSONMetadataKey] as? AirshipJSON,
            let unwrapped = json.unWrap() as? [String: AnyHashable]
        {
            event.conversionSendID = unwrapped["_"] as? String
            event.conversionPushMetadata = unwrapped["com.urbanairship.metadata"] as? String
        }

        guard event.isValid() else {
            throw AirshipErrors.error("Invalid custom event: \(arguments.value)")
        }

        event.track()

        return nil
    }

    func parseString(_ dict: [AnyHashable: Any], key: String) -> String? {
        guard let value = dict[key] else {
            return nil
        }

        guard value is String else {
            return "\(value)"
        }
        return value as? String
    }

    func parseDouble(_ dict: [AnyHashable: Any], key: String) -> Double? {
        guard let value = dict[key] else {
            return nil
        }

        guard let value = value as? Double else {
            if let string = parseString(dict, key: key) {
                return Double(string)
            }
            return nil
        }
        return value
    }
    
    private func getEventName(_ dict: [AnyHashable: Any]) -> String? {
        return parseString(dict, key: Self.eventNameKey)
        ?? parseString(dict, key: CustomEvent.eventNameKey)
    }
    
    private func getEventValue(_ dict: [AnyHashable: Any]) -> Double? {
        return parseDouble(dict, key: Self.eventValue)
        ?? parseDouble(dict, key: CustomEvent.eventValueKey)
    }
}
