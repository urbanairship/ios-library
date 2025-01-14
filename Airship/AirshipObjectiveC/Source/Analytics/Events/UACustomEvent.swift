/* Copyright Airship and Contributors */

public import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// CustomEvent captures information regarding a custom event for
/// Analytics.
@objc
public class UACustomEvent: NSObject {
    
    var customEvent: CustomEvent

    /**
     * The event's value. The value must be between -2^31 and
     * 2^31 - 1 or it will invalidate the event.
     */
    @objc
    public var eventValue: Decimal {
        get {
           return customEvent.eventValue
        }
        set {
            customEvent.eventValue = newValue
        }
    }

    /**
     * The event's name. The name's length must not exceed 255 characters or it will
     * invalidate the event.
     */
    @objc
    public var eventName: String {
        get {
           return customEvent.eventName
        }
        set {
            customEvent.eventName = newValue
        }
    }

    /**
     * The event's transaction ID. The ID's length must not exceed 255 characters or it will
     * invalidate the event.
     */
    @objc
    public var transactionID: String? {
        get {
           return customEvent.transactionID
        }
        set {
            customEvent.transactionID = newValue
        }
    }

    /**
     * The event's interaction type. The type's length must not exceed 255 characters or it will
     * invalidate the event.
     */
    @objc
    public var interactionType: String? {
        get {
           return customEvent.interactionType
        }
        set {
            customEvent.interactionType = newValue
        }
    }

    /**
     * The event's interaction ID. The ID's length must not exceed 255 characters or it will
     * invalidate the event.
     */
    @objc
    public var interactionID: String? {
        get {
           return customEvent.interactionID
        }
        set {
            customEvent.interactionID = newValue
        }
    }

    /**
     * The event's properties. Properties must be valid JSON.
     */
    @objc
    public var properties: [String: Any] {
        get {
            return customEvent.properties.mapValues { $0.unWrap() as Any }
        }
    }

    /// Default constructor.
    /// - Parameter name: The name of the event. The event's name must not exceed
    /// 255 characters or it will invalidate the event.
    @objc
    public convenience init(name: String) {
        let customEvent = CustomEvent(name: name)
        self.init(event: customEvent)
    }

    /// Default constructor.
    /// - Parameter name: The name of the event. The event's name must not exceed
    /// 255 characters or it will invalidate the event.
    /// - Parameter value: The event value. The value must be between -2^31 and
    /// 2^31 - 1 or it will invalidate the event. Defaults to 1.
    @objc
    public convenience init(name: String, value: Double) {
        let customEvent = CustomEvent(name: name, value: value)
        self.init(event: customEvent)
    }

    /// Default constructor.
    /// - Parameter name: The name of the event. The event's name must not exceed
    /// 255 characters or it will invalidate the event.
    /// - Parameter decimalValue: The event value. The value must be between -2^31 and
    /// 2^31 - 1 or it will invalidate the event. Defaults to 1.
    @objc
    public convenience init(name: String, decimalValue: Decimal) {
        let customEvent = CustomEvent(name: name, decimalValue: decimalValue)
        self.init(event: customEvent)
    }

    init(event: CustomEvent) {
        self.customEvent = event
    }
    
    @objc
    public func isValid() -> Bool {
        return customEvent.isValid()
    }

    /**
     * Adds the event to analytics.
     */
    @objc
    public func track() {
        customEvent.track()
    }

    /// Sets a property string value.
    /// - Parameters:
    ///     - string: The string value to set.
    ///     - forKey: The properties key
    @objc
    public func setProperty(
        string: String,
        forKey key: String
    ) {
        customEvent.setProperty(string: string, forKey: key)
    }

    /// Removes a property.
    /// - Parameters:
    ///     - forKey: The properties key
    @objc
    public func removeProperty(
        forKey key: String
    ) {
        customEvent.removeProperty(forKey: key)
    }

    /// Sets a property double value.
    /// - Parameters:
    ///     - double: The double value to set.
    ///     - forKey: The properties key
    @objc
    public func setProperty(
        double: Double,
        forKey key: String
    ) {
        customEvent.setProperty(double: double, forKey: key)
    }

    /// Sets a property bool value.
    /// - Parameters:
    ///     - bool: The bool value to set.
    ///     - forKey: The properties key
    @objc
    public func setProperty(
        bool: Bool,
        forKey key: String
    ) {
        customEvent.setProperty(bool: bool, forKey: key)
    }

    /// Sets a property value.
    /// - Parameters:
    ///     - value: The value to set.
    ///     - forKey: The properties key
    @objc
    public func setProperty(
        value: Any,
        forKey key: String
    ) throws {
        try customEvent.setProperty(value: value, forKey: key)
    }

    /// Sets a property value.
    /// - Parameters:
    ///     - value: The values to set. The value must result in a JSON object or an error will be thrown.
    @objc
    public func setProperties(_ object: Any) throws {
        try customEvent.setProperties(object)
    }
}
