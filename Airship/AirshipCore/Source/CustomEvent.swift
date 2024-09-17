/* Copyright Airship and Contributors */

/// CustomEvent captures information regarding a custom event for
/// Analytics.
public class CustomEvent: NSObject {

    /// The event type
    public static let eventType: String  = "enhanced_custom_event"

    private static let interactionMCRAP = "ua_mcrap"

    /**
     * The max properties size in bytes.
     */
    public static let maxPropertiesSize = 65536

    // Public data keys
    public static let eventNameKey = "event_name"
    public static let eventValueKey = "event_value"
    public static let eventPropertiesKey = "properties"
    public static let eventTransactionIDKey = "transaction_id"
    public static let eventInteractionIDKey = "interaction_id"
    public static let eventInteractionTypeKey = "interaction_type"

    static let eventInAppKey = "in_app"

    // Private data keys
    static let eventConversionMetadataKey = "conversion_metadata"
    static let eventConversionSendIDKey = "conversion_send_id"
    static let eventTemplateTypeKey = "template_type"

    /**
     * The send ID that triggered the event.
     * - Note: For internal use only. :nodoc:
     */
    public var conversionSendID: String?

    /**
     * The conversion push metadata.
     * - Note: For internal use only. :nodoc:
     */
    public var conversionPushMetadata: String?

    /**
     * The event's template type. The template type's length must not exceed 255 characters or it will
     * invalidate the event.
     * - Note: For internal use only. :nodoc:
     */
    public var templateType: String?

    private var _eventValue: NSDecimalNumber?

    public static var defaultEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }


    /// The in-app message context for custom event attribution
    /// NOTE: For internal use only. :nodoc:
    var inApp: AirshipJSON?
    
    /**
     * The event's value. The value must be between -2^31 and
     * 2^31 - 1 or it will invalidate the event.
     */
    public var eventValue: NSNumber? {
        get {
            return self._eventValue
        }
        set {
            if let newValue = newValue {
                if let decimal = newValue as? NSDecimalNumber {
                    self._eventValue = decimal
                } else {
                    let converted = NSDecimalNumber.init(
                        decimal: newValue.decimalValue
                    )
                    self._eventValue = converted
                }
            } else {
                self._eventValue = nil
            }
        }
    }

    private lazy var analytics = Airship.requireComponent(
        ofType: AirshipAnalyticsProtocol.self
    )

    /**
     * The event's name. The name's length must not exceed 255 characters or it will
     * invalidate the event.
     */
    public var eventName: String?

    /**
     * The event's transaction ID. The ID's length must not exceed 255 characters or it will
     * invalidate the event.
     */
    public var transactionID: String?

    /**
     * The event's interaction type. The type's length must not exceed 255 characters or it will
     * invalidate the event.
     */
    public var interactionType: String?

    /**
     * The event's interaction ID. The ID's length must not exceed 255 characters or it will
     * invalidate the event.
     */
    public var interactionID: String?

    /**
     * The event's properties. Properties must be valid JSON.
     */
    public var properties: [String: Any] = [:]

    public var data: [AnyHashable: Any] {
        return self.eventBody(
            sendID: self.analytics.conversionSendID,
            metadata: self.analytics.conversionPushMetadata,
            formatValue: true
        ).unWrap() as? [AnyHashable : Any] ?? [:]
    }

    /**
     * Constructor for testing. :nodoc:
     *
     * - Parameter name: The name of the event. The event's name must not exceed
     * 255 characters or it will invalidate the event.
     * - Parameter value: The event value.
     * - Returns: A Custom event instance
     */
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
    public convenience init(name: String, stringValue: String?) {
        let decimalValue =
            stringValue != nil ? NSDecimalNumber(string: stringValue) : nil
        self.init(name: name, value: decimalValue)
    }

    /**
     * Constructor.
     *
     * - Parameter name: The name of the event. The event's name must not exceed
     * 255 characters or it will invalidate the event.
     */
    public convenience init(name: String) {
        self.init(name: name, value: nil)
    }

    /**
     * Factory method for creating a custom event.
     *
     * - Parameter name: The name of the event. The event's name must not exceed
     * 255 characters or it will invalidate the event.
     * - Returns: A Custom event instance
     */
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
    public class func event(name: String, value: NSNumber?) -> CustomEvent {
        guard let value else {
            return CustomEvent(name: name)
        }

         if let decimal = value as? NSDecimalNumber {
            return CustomEvent(name: name, value: decimal)
        } else {
            let converted = NSDecimalNumber(decimal: value.decimalValue)
            return CustomEvent(name: name, value: converted)
        }
    }

    public func isValid() -> Bool {
        let areFieldsValid = validateFields()
        let isValueValid = validateValue()
        let areProperitiesValid = validateProperties()
        return areFieldsValid && isValueValid && areProperitiesValid
    }

    /**
     * Sets the custom event's interaction type and identifier as coming from a Message Center message.
     * - Parameter messageID: The message ID.
     * - Note: For internal use only. :nodoc:
     */
    public func setInteractionFromMessageCenterMessage(_ messageID: String?) {
        self.interactionID = messageID
        self.interactionType = CustomEvent.interactionMCRAP
    }

    /**
     * - Note: For internal use only. :nodoc:
     */
    func eventBody(sendID: String?, metadata: String?, formatValue: Bool) -> AirshipJSON {
        var wrappedProperities: AirshipJSON? = nil

        do {
            wrappedProperities = try AirshipJSON.wrap(properties, encoder: Self.defaultEncoder)
        } catch {
            AirshipLogger.error("Failed to wrap properites \(properties): \(error)")
        }

        return AirshipJSON.makeObject { object in
            object.set(string: eventName, key: CustomEvent.eventNameKey)
            object.set(string: conversionSendID ?? sendID, key: CustomEvent.eventConversionSendIDKey)
            object.set(string: conversionPushMetadata ?? metadata, key: CustomEvent.eventConversionMetadataKey)
            object.set(string: interactionID, key: CustomEvent.eventInteractionIDKey)
            object.set(string: interactionType, key: CustomEvent.eventInteractionTypeKey)
            object.set(string: transactionID, key: CustomEvent.eventTransactionIDKey)
            object.set(string: templateType, key: CustomEvent.eventTemplateTypeKey)
            object.set(json: wrappedProperities, key: CustomEvent.eventPropertiesKey)
            object.set(json: inApp, key: CustomEvent.eventInAppKey)

            if formatValue {
                let number = (self._eventValue ?? 1.0).multiplying(byPowerOf10: 6)
                object.set(double: Double(number.int64Value), key: CustomEvent.eventValueKey)
            } else {
                object.set(double: eventValue?.doubleValue ?? 1.0, key: CustomEvent.eventValueKey)
            }
        }
    }

    /**
     * Adds the event to analytics.
     */
    public func track() {
        self.analytics.recordCustomEvent(self)
    }

    public override var debugDescription: String {
        "CustomEvent(data: \(self.eventBody(sendID: nil, metadata: nil, formatValue: false)))"
    }
    
    private func validateValue() -> Bool {
        if let eventValue = self._eventValue {
            if eventValue == NSDecimalNumber.notANumber {
                AirshipLogger.error("Event value is not a number.")
                return false
            }

            if eventValue.compare(NSNumber(value: Int32.max)).rawValue > 0 {
                AirshipLogger.error(
                    "Event value \(eventValue) is larger than 2^31-1."
                )
                return false
            }

            if eventValue.compare(NSNumber(value: Int32.min)).rawValue < 0 {
                AirshipLogger.error(
                    "Event value \(eventValue) is smaller than -2^31."
                )
                return false
            }
        }

        return true
    }

    private func validateProperties() -> Bool {
        do {
            let encodedProperties = try AirshipJSON.wrap(properties, encoder: Self.defaultEncoder).toData()
            if encodedProperties.count > CustomEvent.maxPropertiesSize {
                AirshipLogger.error(
                    "Event properties (%lu bytes) are larger than the maximum size of \(CustomEvent.maxPropertiesSize) bytes."
                )
                return false
            }
        } catch {
            AirshipLogger.error("Event properties serialization error \(error)")
            return false
        }
        return true
    }

    private func validateFields() -> Bool {
        let fields: [(name: String, value: String?, required: Bool)] =  [
            (name: "eventName", value: self.eventName, required: true),
            (name: "interactionType", value: self.interactionType, required: false),
            (name: "interactionID", value: self.interactionID, required: false),
            (name: "transactionID", value: self.transactionID, required: false),
            (name: "templateType", value: self.templateType, required: false),
            (name: "transactionID", value: self.templateType, required: false)
        ]

        let mapped = fields.map { field in
            if field.required, (field.value?.count ?? 0) == 0 {
                AirshipLogger.error("Missing required field \(field.name)")
                return false
            }

            if let value = field.value {
                if value.count > 255 {
                    AirshipLogger.error(
                        "Field \(field.name) must be between 0 and 255 characters."
                    )
                    return false
                }
            }

            return true
        }

        return !mapped.contains(false)
    }
}
