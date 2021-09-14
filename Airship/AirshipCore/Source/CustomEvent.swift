/* Copyright Airship and Contributors */

/**
 * CustomEvent captures information regarding a custom event for
 * Analytics.
 */
@objc(UACustomEvent)
public class CustomEvent : NSObject, Event {

    private static let interactionMCRAP = "ua_mcrap"

    /**
     * The max number of properties.
     */
    @objc
    public static let maxPropertiesSize = 65536

    // Public data keys
    @objc
    public static let eventNameKey = "event_name"
    @objc
    public static let eventValueKey = "event_value"
    @objc
    public static let eventPropertiesKey = "properties"
    @objc
    public static let eventTransactionIDKey = "transaction_id"
    @objc
    public static let eventInteractionIDKey = "interaction_id"
    @objc
    public static let eventInteractionTypeKey = "interaction_type"

    // Private data keys
    static let eventConversionMetadataKey = "conversion_metadata"
    static let eventConversionSendIDKey = "conversion_send_id"
    static let eventTemplateTypeKey = "template_type"


    /**
     * The send ID that triggered the event.
     * - Note: For internal use only. :nodoc:
     */
    @objc
    public var conversionSendID: String?

    /**
     * The conversion push metadata.
     * - Note: For internal use only. :nodoc:
     */
    @objc
    public var conversionPushMetadata: String?

    /**
     * The event's template type. The template type's length must not exceed 255 characters or it will
     * invalidate the event.
     * - Note: For internal use only. :nodoc:
     */
    @objc
    public var templateType: String?

    private var _eventValue : NSDecimalNumber?

    /**
     * The event's value. The value must be between -2^31 and
     * 2^31 - 1 or it will invalidate the event.
     */
    @objc
    public var eventValue : NSNumber? {
        get {
            return self._eventValue
        }
        set {
            if let newValue = newValue {
                if let decimal = newValue as? NSDecimalNumber  {
                    self._eventValue = decimal
                } else {
                    let converted = NSDecimalNumber.init(decimal: newValue.decimalValue)
                    self._eventValue = converted
                }
            } else {
                self._eventValue = nil
            }
        }
    }

    private lazy var analytics = Airship.requireComponent(ofType: AnalyticsProtocol.self)

    
    /**
     * The event's name. The name's length must not exceed 255 characters or it will
     * invalidate the event.
     */
    @objc
    public var eventName: String?

    /**
     * The event's transaction ID. The ID's length must not exceed 255 characters or it will
     * invalidate the event.
     */
    @objc
    public var transactionID: String?

    /**
     * The event's interaction type. The type's length must not exceed 255 characters or it will
     * invalidate the event.
     */
    @objc
    public var interactionType: String?

    /**
     * The event's interaction ID. The ID's length must not exceed 255 characters or it will
     * invalidate the event.
     */
    @objc
    public var interactionID: String?

    /**
     * The event's properties. Properties must be valid JSON.
     */
    @objc
    public var properties : [String: Any] = [:]

    @objc
    public var eventType : String {
        get {
            return "enhanced_custom_event"
        }
    }

    @objc
    public var priority: EventPriority {
        get {
            return .normal
        }
    }

    /**
     * Constructor for testing. :nodoc:
     *
     * - Parameter name: The name of the event. The event's name must not exceed
     * 255 characters or it will invalidate the event.
     * - Parameter value: The event value.
     * - Returns: A Custom event instance
     */
    @objc
    public init(name: String, value: NSNumber?) {
        self.eventName = name
        super.init()
        self.eventValue = value
    }

    /**
     * Constructor
     *
     * - Parameter name: The name of the event. The event's name must not exceed
     * 255 characters or it will invalidate the event.
     * - Parameter stringValue: The value of the event as a string. The value must be a valid
     * number between -2^31 and 2^31 - 1 or it will invalidate the event.
     * - Returns: A Custom event instance
     */
    @objc
    public convenience init(name: String, stringValue: String?) {
        let decimalValue = stringValue != nil ? NSDecimalNumber(string: stringValue) : nil
        self.init(name: name, value: decimalValue)
    }

    /**
     * Constructor.
     *
     * - Parameter name: The name of the event. The event's name must not exceed
     * 255 characters or it will invalidate the event.
     */
    public convenience init(name:  String) {
        self.init(name: name, value: nil)
    }

    /**
     * Factory method for creating a custom event.
     *
     * - Parameter name: The name of the event. The event's name must not exceed
     * 255 characters or it will invalidate the event.
     * - Returns: A Custom event instance
     */
    @objc(eventWithName:)
    public class func event(name: String) -> CustomEvent {
        return CustomEvent(name: name)
    }

    /**
     * Factory method for creating a custom event with a value from a string.
     *
     * - Parameter name: The name of the event. The event's name must not exceed
     * 255 characters or it will invalidate the event.
     * - Parameter string: The value of the event as a string. The value must be a valid
     * number between -2^31 and 2^31 - 1 or it will invalidate the event.
     * - Returns: A Custom event instance
     */
    @objc(eventWithName:valueFromString:)
    public class func event(name: String, string: String?) -> CustomEvent {
        return CustomEvent(name: name, stringValue: string)
    }

    /**
     * Factory method for creating a custom event with a value.
     *
     * - Parameter name: The name of the event. The event's name must not exceed
     * 255 characters or it will invalidate the event.
     * - Parameter value: The value of the event. The value must be between -2^31 and
     * 2^31 - 1 or it will invalidate the event.
     * - Returns: A Custom event instance
     */
    @objc(eventWithName:value:)
    public class func event(name: String, value: NSNumber?) -> CustomEvent {
        if (value == nil) {
            return CustomEvent(name: name)
        } else if let decimal = value as? NSDecimalNumber  {
            return CustomEvent(name: name, value: decimal)
        } else {
            let converted = NSDecimalNumber.init(decimal: value!.decimalValue)
            return CustomEvent(name: name, value: converted)
        }
    }

    @objc
    public func isValid() -> Bool {
        var isValid = true
        isValid = self.isValid(string: self.eventName, name: "eventName", required: true) && isValid
        isValid = self.isValid(string: self.interactionType, name: "interactionType", required: false) && isValid
        isValid = self.isValid(string: self.interactionID, name: "interactionID", required: false) && isValid
        isValid = self.isValid(string: self.transactionID, name: "transactionID", required: false) && isValid
        isValid = self.isValid(string: self.templateType, name: "templateType", required: false) && isValid

        if let eventValue = self._eventValue {
            if eventValue == NSDecimalNumber.notANumber {
                AirshipLogger.error("Event value is not a number.")
                isValid = false
            } else if (eventValue.compare(NSNumber(value: Int32.max)).rawValue > 0) {
                AirshipLogger.error("Event value \(eventValue) is larger than 2^31-1.")
                isValid = false
            } else if (eventValue.compare(NSNumber(value: Int32.min)).rawValue < 0) {
                AirshipLogger.error("Event value \(eventValue) is smaller than -2^31.")
                isValid = false
            }
        }

        do {
            let propertyData = try JSONSerialization.data(withJSONObject: properties, options: [])
            if (propertyData.count > CustomEvent.maxPropertiesSize) {
                AirshipLogger.error("Event properties (%lu bytes) are larger than the maximum size of \(CustomEvent.maxPropertiesSize) bytes.")
                isValid = false
            }
        } catch {
            AirshipLogger.error("Event properties serialization error \(error)")
            isValid = false
        }

        return isValid
    }

    /**
     * Sets the custom event's interaction type and identifier as coming from a Message Center message.
     * - Parameter messageID: The message ID.
     * - Note: For internal use only. :nodoc:
     */
    @objc
    public func setInteractionFromMessageCenterMessage(_ messageID: String?) {
        self.interactionID = messageID
        self.interactionType = CustomEvent.interactionMCRAP
    }

    @objc
    public var data : [AnyHashable : Any] {
        get {
            let sendID = conversionSendID ?? self.analytics.conversionSendID
            let sendMetadata = conversionPushMetadata ?? self.analytics.conversionPushMetadata

            var dictionary: [AnyHashable : Any] = [:]
            dictionary[CustomEvent.eventNameKey] = eventName
            dictionary[CustomEvent.eventConversionSendIDKey] = sendID
            dictionary[CustomEvent.eventConversionMetadataKey] = sendMetadata
            dictionary[CustomEvent.eventInteractionIDKey] = interactionID
            dictionary[CustomEvent.eventInteractionTypeKey] = interactionType
            dictionary[CustomEvent.eventTransactionIDKey] = transactionID
            dictionary[CustomEvent.eventTemplateTypeKey] = templateType
            dictionary[CustomEvent.eventPropertiesKey] = properties

            if let eventValue = self._eventValue {
                let number = eventValue.multiplying(byPowerOf10: 6)
                dictionary[CustomEvent.eventValueKey] = number.int64Value
            }

            return dictionary
        }
    }

    /**
     * - Note: For internal use only. :nodoc:
     */
    @objc
    public var payload : [AnyHashable : Any] {
        get {
            /*
             * We are unable to use the event.data for automation because we modify some
             * values to be stringified versions before we store the event to be sent to
             * warp9. Instead we are going to recreate the event data with the unmodified
             * values.
             */
            var eventData: [AnyHashable : Any] = [:]
            eventData[CustomEvent.eventNameKey] = eventName
            eventData[CustomEvent.eventInteractionIDKey] = interactionID
            eventData[CustomEvent.eventInteractionTypeKey] = interactionType
            eventData[CustomEvent.eventTransactionIDKey] = transactionID
            eventData[CustomEvent.eventValueKey] = eventValue
            eventData[CustomEvent.eventPropertiesKey] = properties
            return eventData
        }
    }

    /**
     * Adds the event to analytics.
     */
    @objc
    public func track() {
        self.analytics.addEvent(self)
    }

    private func isValid(string: String?, name: String, required: Bool = false) -> Bool {
        guard let string = string else {
            if (required) {
                AirshipLogger.error("Missing requied field \(name)")
                return false
            } else {
                return true
            }
        }

        guard (!required || string.count > 0) && string.count <= 255 else {
            AirshipLogger.error("Field \(name) must be between \(required ? 1 : 0) and 255 characters.")
            return false
        }

        return true
    }
}
