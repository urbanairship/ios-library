/* Copyright Airship and Contributors */

/**
 * An action that adds a custom event.
 *
 * This action is registered under the name "add_custom_event_action".
 *
 * Expected argument values: A dictionary of keys for the custom event. When a
 * custom event action is triggered from a Message Center Rich Push Message,
 * the interaction type and ID will automatically be filled for the message if
 * they are left blank.
 *
 * Valid situations: UASituationForegroundPush, UASituationLaunchedFromPush,
 * UASituationWebViewInvocation, UASituationManualInvocation, UASituationBackgroundPush,
 * UASituationForegroundInteractiveButton, UASituationBackgroundInteractiveButton,
 * and UASituationAutomation
 *
 *
 * Result value: nil
 *
 * Fetch result: UAActionFetchResultNoData
 *
 * Default predicate: Only accepts UASituationWebViewInvocation and UASituationManualInvocation
 *
 */
@objc(UAAddCustomEventAction)
public class AddCustomEventAction : NSObject, Action {
    
    @objc
    public static let name = "add_custom_event_action"

    
    public func acceptsArguments(_ arguments: ActionArguments) -> Bool {
        guard let dict = arguments.value as? [AnyHashable : Any] else {
            AirshipLogger.error("UAAddCustomEventAction requires a dictionary of event data.")
            return false
        }
        
        guard dict[CustomEvent.eventNameKey] is String else {
            AirshipLogger.error("UAAddCustomEventAction requires an event name in the event data.")
            return false
        }
        
        return true
    }

    public func perform(with arguments: ActionArguments, completionHandler: UAActionCompletionHandler) {
        let dict = arguments.value as? [AnyHashable : Any]
        let eventName = parseString(dict, key: CustomEvent.eventNameKey) ?? ""
        let eventValue = parseString(dict, key: CustomEvent.eventValueKey)
        let interactionID = parseString(dict, key: CustomEvent.eventInteractionIDKey)
        let interactionType = parseString(dict, key: CustomEvent.eventInteractionTypeKey)
        let transactionID = parseString(dict, key: CustomEvent.eventTransactionIDKey)
        let properties = dict?[CustomEvent.eventPropertiesKey] as? [String : Any]

        let event = CustomEvent(name: eventName, stringValue: eventValue)
        
        event.transactionID = transactionID
        event.properties = properties ?? [:]
        
        if (interactionID != nil || interactionType != nil) {
            event.interactionType = interactionType
            event.interactionID = interactionID
        } else if let messageID = arguments.metadata?[UAActionMetadataInboxMessageIDKey] as? String {
            event.setInteractionFromMessageCenterMessage(messageID)
        }
        
        if let pushPaylaod = arguments.metadata?[UAActionMetadataPushPayloadKey] as? [AnyHashable : Any] {
            event.conversionSendID = pushPaylaod["_"] as? String
            event.conversionPushMetadata = pushPaylaod["com.urbanairship.metadata"] as? String
        }
        
        if event.isValid() {
            event.track()
            completionHandler(ActionResult.empty())
        } else {
            let error = AirshipErrors.error("Invalid custom event \(arguments.value ?? "")")
            completionHandler(ActionResult(error: error))
        }
    }

    func parseString(_ dict: [AnyHashable : Any]?, key: String) -> String? {
        guard let value = dict?[key] else {
            return nil
        }
        
        if value is String {
            return value as? String
        } else {
            return "\(value)"
        }
    }
}
