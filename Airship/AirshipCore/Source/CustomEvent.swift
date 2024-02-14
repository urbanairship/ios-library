/* Copyright Airship and Contributors */

/// CustomEvent captures information regarding a custom event for
/// Analytics.
@objc(UACustomEvent)
public class CustomEvent: NSObject {

    /// The event type
    public static let eventType: String  = "enhanced_custom_event"

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

    private var _eventValue: NSDecimalNumber?

    /**
     * The event's value. The value must be between -2^31 and
     * 2^31 - 1 or it will invalidate the event.
     */
    @objc
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
    public var properties: [String: Any] = [:]

    @objc
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
        if value == nil {
            return CustomEvent(name: name)
        } else if let decimal = value as? NSDecimalNumber {
            return CustomEvent(name: name, value: decimal)
        } else {
            let converted = NSDecimalNumber.init(decimal: value!.decimalValue)
            return CustomEvent(name: name, value: converted)
        }
    }

    @objc
    public func isValid() -> Bool {
        var isValid = true
        isValid =
            self.isValid(
                string: self.eventName,
                name: "eventName",
                required: true
            )
            && isValid
        isValid =
            self.isValid(
                string: self.interactionType,
                name: "interactionType",
                required: false
            ) && isValid
        isValid =
            self.isValid(
                string: self.interactionID,
                name: "interactionID",
                required: false
            ) && isValid
        isValid =
            self.isValid(
                string: self.transactionID,
                name: "transactionID",
                required: false
            ) && isValid
        isValid =
            self.isValid(
                string: self.templateType,
                name: "templateType",
                required: false
            ) && isValid

        if let eventValue = self._eventValue {
            if eventValue == NSDecimalNumber.notANumber {
                AirshipLogger.error("Event value is not a number.")
                isValid = false
            } else if eventValue.compare(NSNumber(value: Int32.max)).rawValue
                > 0
            {
                AirshipLogger.error(
                    "Event value \(eventValue) is larger than 2^31-1."
                )
                isValid = false
            } else if eventValue.compare(NSNumber(value: Int32.min)).rawValue
                < 0
            {
                AirshipLogger.error(
                    "Event value \(eventValue) is smaller than -2^31."
                )
                isValid = false
            }
        }

        do {
            let propertyData = try JSONSerialization.data(
                withJSONObject: properties,
                options: []
            )
            if propertyData.count > CustomEvent.maxPropertiesSize {
                AirshipLogger.error(
                    "Event properties (%lu bytes) are larger than the maximum size of \(CustomEvent.maxPropertiesSize) bytes."
                )
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

    /**
     * - Note: For internal use only. :nodoc:
     */
    func eventBody(sendID: String?, metadata: String?, formatValue: Bool) -> AirshipJSON {
        var wrappedProperities: AirshipJSON? = nil

        do {
            wrappedProperities = try AirshipJSON.wrap(properties)
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
    @objc
    public func track() {
        self.analytics.recordCustomEvent(self)
    }

    private func isValid(
        string: String?,
        name: String,
        required: Bool = false
    ) -> Bool {
        guard let string = string else {
            guard required else {
                return true
            }
            AirshipLogger.error("Missing required field \(name)")
            return false
        }

        guard (!required || string.count > 0) && string.count <= 255 else {
            AirshipLogger.error(
                "Field \(name) must be between \(required ? 1 : 0) and 255 characters."
            )
            return false
        }

        return true
    }
}
