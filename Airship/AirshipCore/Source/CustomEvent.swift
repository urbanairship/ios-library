/* Copyright Airship and Contributors */



/// CustomEvent captures information regarding a custom event for
/// Analytics.
public struct CustomEvent: Sendable {

    /// Max properties size in bytes
    public static let maxPropertiesSize = 65536

    static let eventNameKey = "event_name"
    static let eventValueKey = "event_value"
    static let eventPropertiesKey = "properties"
    static let eventTransactionIDKey = "transaction_id"
    static let eventInteractionIDKey = "interaction_id"
    static let eventInteractionTypeKey = "interaction_type"
    static let eventInAppKey = "in_app"
    static let eventConversionMetadataKey = "conversion_metadata"
    static let eventConversionSendIDKey = "conversion_send_id"
    static let eventTemplateTypeKey = "template_type"
    static let eventType: String  = "enhanced_custom_event"
    static let interactionMCRAP = "ua_mcrap"

    /// Internal conversion send ID
    var conversionSendID: String?

    /// Internal conversion push metadata
    var conversionPushMetadata: String?

    /// Template type
    var templateType: String?

    /// The in-app message context for custom event attribution
    var inApp: AirshipJSON?

    /// Default encoder. Uses `iso8601` date encoding strategy.
    public static func defaultEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    /// The event's value. The value must be between -2^31 and
    /// 2^31 - 1 or it will invalidate the event.
    public var eventValue: Decimal

    /// The event's name. The name's length must not exceed 255 characters or it will  or it will
    /// invalidate the event.
    public var eventName: String

    /// The event's transaction ID. The ID's length must not exceed 255 characters or it will
    /// invalidate the event.
    public var transactionID: String?

    /// The event's interaction type. The type's length must not exceed 255 characters or it will
    /// invalidate the event.
    public var interactionType: String?

    /// The event's interaction ID. The ID's length must not exceed 255 characters or it will
    /// invalidate the event.
    public var interactionID: String?

    /// The event's properties.
    public private(set) var properties: [String: AirshipJSON] = [:]

    /// Sets a property string value.
    /// - Parameters:
    ///     - string: The string value to set.
    ///     - forKey: The properties key
    public mutating func setProperty(
        string: String,
        forKey key: String
    ) {
        properties[key] = .string(string)
    }

    /// Removes a property.
    /// - Parameters:
    ///     - forKey: The properties key
    public mutating func removeProperty(
        forKey key: String
    ) {
        properties[key] = nil
    }

    /// Sets a property double value.
    /// - Parameters:
    ///     - double: The double value to set.
    ///     - forKey: The properties key
    public mutating func setProperty(
        double: Double,
        forKey key: String
    ) {
        properties[key] = .number(double)
    }

    /// Sets a property bool value.
    /// - Parameters:
    ///     - bool: The bool value to set.
    ///     - forKey: The properties key
    public mutating func setProperty(
        bool: Bool,
        forKey key: String
    ) {
        properties[key] = .bool(bool)
    }

    /// Sets a property value.
    /// - Parameters:
    ///     - value: The value to set.
    ///     - forKey: The properties key
    ///     - encoder: JSONEncoder to use.'
    public mutating func setProperty(
        value: Any,
        forKey key: String,
        encoder: @autoclosure () -> JSONEncoder = Self.defaultEncoder()
    ) throws {
        properties[key] = try AirshipJSON.wrap(value, encoder: encoder())
    }

    /// Sets a property value.
    /// - Parameters:
    ///     - value: The values to set. The value must result in a JSON object or an error will be thrown.
    ///     - encoder: JSONEncoder to use.
    public mutating func setProperties(
        _ object: Any,
        encoder: @autoclosure () -> JSONEncoder = Self.defaultEncoder()
    ) throws {
        let json = try AirshipJSON.wrap(object, encoder: encoder())
        guard json.isObject, let properties = json.object else {
            throw AirshipErrors.error("Properties must be an object")
        }

        self.properties = properties
    }

    /// Default constructor.
    /// - Parameter name: The name of the event. The event's name must not exceed
    /// 255 characters or it will invalidate the event.
    /// - Parameter value: The event value. The value must be between -2^31 and
    /// 2^31 - 1 or it will invalidate the event. Defaults to 1.
    public init(name: String, value: Double = 1.0) {
        self.eventName = name
        if value.isFinite {
            self.eventValue = Decimal(value)
        } else {
            self.eventValue = Decimal(1.0)
        }
    }

    /// Default constructor.
    /// - Parameter name: The name of the event. The event's name must not exceed
    /// 255 characters or it will invalidate the event.
    /// - Parameter value: The event value. The value must be between -2^31 and
    /// 2^31 - 1 or it will invalidate the event. Defaults to 1.
    public init(name: String, decimalValue: Decimal) {
        self.eventName = name
        self.eventValue = decimalValue
    }
}

extension CustomEvent {
    public func isValid() -> Bool {
        let areFieldsValid = validateFields()
        let isValueValid = validateValue()
        let areProperitiesValid = validateProperties()
        return areFieldsValid && isValueValid && areProperitiesValid
    }

    mutating func setInteractionFromMessageCenterMessage(_ messageID: String) {
        self.interactionID = messageID
        self.interactionType = CustomEvent.interactionMCRAP
    }

    /**
     * - Note: For internal use only. :nodoc:
     */
    func eventBody(sendID: String?, metadata: String?, formatValue: Bool) -> AirshipJSON {
        return AirshipJSON.makeObject { object in
            object.set(string: eventName, key: CustomEvent.eventNameKey)
            object.set(string: conversionSendID ?? sendID, key: CustomEvent.eventConversionSendIDKey)
            object.set(string: conversionPushMetadata ?? metadata, key: CustomEvent.eventConversionMetadataKey)
            object.set(string: interactionID, key: CustomEvent.eventInteractionIDKey)
            object.set(string: interactionType, key: CustomEvent.eventInteractionTypeKey)
            object.set(string: transactionID, key: CustomEvent.eventTransactionIDKey)
            object.set(string: templateType, key: CustomEvent.eventTemplateTypeKey)
            object.set(json: .object(properties), key: CustomEvent.eventPropertiesKey)
            object.set(json: inApp, key: CustomEvent.eventInAppKey)

            if formatValue {
                let number = (self.eventValue as NSDecimalNumber).multiplying(byPowerOf10: 6)
                object.set(double: number.doubleValue.rounded(.down), key: CustomEvent.eventValueKey)
            } else {
                object.set(double: (self.eventValue as NSDecimalNumber).doubleValue, key: CustomEvent.eventValueKey)
            }
        }
    }

    /**
     * Adds the event to analytics. A wrapper arou
     */
    public func track() {
        Airship.analytics.recordCustomEvent(self)
    }

    private func validateValue() -> Bool {
        if !eventValue.isFinite {
            AirshipLogger.error("Event value \(eventValue) is not finite.")
            return false
        }

        if eventValue > Decimal(Int32.max) {
            AirshipLogger.error(
                "Event value \(eventValue) is larger than 2^31-1."
            )
            return false
        }

        if eventValue < Decimal(Int32.min) {
            AirshipLogger.error(
                "Event value \(eventValue) is smaller than -2^31."
            )
            return false
        }

        return true
    }

    private func validateProperties() -> Bool {
        do {
            let encodedProperties = try AirshipJSON.object(properties).toData()
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
