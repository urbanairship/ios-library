/* Copyright Airship and Contributors */

import Foundation
public import AirshipCore

/// This singleton provides an interface to the functionality provided by the Airship iOS Push API.
@objc
public class UACustomEvent: NSObject {
    
    private var customEvent: CustomEvent
    
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

    /**
     * The event's value. The value must be between -2^31 and
     * 2^31 - 1 or it will invalidate the event.
     */
    @objc
    public var eventValue: NSNumber? {
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
    public var eventName: String? {
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
           return customEvent.properties
        }
        set {
            customEvent.properties = newValue
        }
    }

    @objc
    public var data: [AnyHashable: Any] {
        get {
           return customEvent.data
        }
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
        let customEvent = CustomEvent(name: name, stringValue: stringValue)
        self.init(event: customEvent)
    }

    /**
     * Factory method for creating a custom event.
     *
     * - Parameter name: The name of the event. The event's name must not exceed
     * 255 characters or it will invalidate the event.
     * - Returns: A Custom event instance
     */
    @objc(eventWithName:)
    public class func event(name: String) -> UACustomEvent {
        let customEvent = CustomEvent(name: name)
        return UACustomEvent(event: customEvent)
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
    public class func event(name: String, string: String?) -> UACustomEvent {
        let customEvent = CustomEvent(name: name, stringValue: string)
        return UACustomEvent(event: customEvent)
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
    public class func event(name: String, value: NSNumber?) -> UACustomEvent {
        let customEvent = CustomEvent(name: name, value: value)
        return UACustomEvent(event: customEvent)
    }

    @objc
    public init(event: CustomEvent) {
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
}
