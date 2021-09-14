/* Copyright Airship and Contributors */

/**
 * AccountEventTemplate represents a custom account event template for the
 * application.
 */
@objc(UAAccountEventTemplate)
public class AccountEventTemplate : NSObject {

    private let eventName: String

    /**
     * The event's value. The value must be between -2^31 and
     * 2^31 - 1 or it will invalidate the event.
     */
    @objc
    public var eventValue: NSNumber?

    /**
     * The event's transaction ID. The transaction ID's length must not exceed 255
     * characters or it will invalidate the event.
     */
    @objc
    public var  transactionID : String?

    /**
     * The event's identifier.
     */
    @objc
    public var userID: String?


    /**
     * The event's category.
     */
    @objc
    public var category: String?

    /**
     * The event's type.
     */
    @objc
    public var type: String?

    private init(eventName: String, value: NSNumber? = nil) {
        self.eventName = eventName
        self.eventValue = value
        super.init()
    }

    /**
     * Factory method for creating a registered account event template.
     * - Returns: An Account event template instance
     */
    @objc
    public class func registeredTemplate() -> AccountEventTemplate {
        return registeredTemplate(value: nil)
    }

    /**
     * Factory method for creating a registered account event template with a value from a string.
     *
     * - Parameter valueString: The value of the event as a string. The value must be a valid
     * number between -2^31 and 2^31 - 1 or it will invalidate the event.
     * - Returns: An Account event template instance
     */
    @objc(registeredTemplateWithValueFromString:)
    public class func registeredTemplate(valueString: String?) -> AccountEventTemplate {
        let decimalValue = valueString != nil ? NSDecimalNumber(string: valueString) : nil
        return registeredTemplate(value: decimalValue)
    }

    /**
     * Factory method for creating a registered account event template with a value.
     *
     * - Parameter value: The value of the event. The value must be between -2^31 and
     * 2^31 - 1 or it will invalidate the event.
     * - Returns: An Account event template instance
     */
    @objc(registeredTemplateWithValue:)
    public class func registeredTemplate(value: NSNumber?) -> AccountEventTemplate {
        return AccountEventTemplate(eventName: "registered_account", value: value)
    }

    /**
     * Factory method for creating a logged in account event template.
     * - Returns: An Account event template instance
     */
    @objc
    public class func loggedInTemplate() -> AccountEventTemplate {
        return loggedInTemplate(value: nil)
    }

    /**
     * Factory method for creating a logged in account event template with a value from a string.
     *
     * - Parameter valueString: The value of the event as a string. The value must be a valid
     * number between -2^31 and 2^31 - 1 or it will invalidate the event.
     * - Returns: An Account event template instance
     */
    @objc(loggedInTemplateWithValueFromString:)
    public class func loggedInTemplate(valueString: String?) -> AccountEventTemplate {
        let decimalValue = valueString != nil ? NSDecimalNumber(string: valueString) : nil
        return loggedInTemplate(value: decimalValue)
    }

    /**
     * Factory method for creating a logged in account event template with a value.
     *
     * - Parameter value: The value of the event. The value must be between -2^31 and
     * 2^31 - 1 or it will invalidate the event.
     * - Returns: An Account event template instance
     */
    @objc(loggedInTemplateWithValue:)
    public class func loggedInTemplate(value: NSNumber?) -> AccountEventTemplate {
        return AccountEventTemplate(eventName: "logged_in", value: value)
    }


    /**
     * Factory method for creating a logged out account event template.
     * - Returns: An Account event template instance
     */
    @objc
    public class func loggedOutTemplate() -> AccountEventTemplate {
        return loggedOutTemplate(value: nil)
    }

    /**
     * Factory method for creating a logged out account event template with a value from a string.
     *
     * - Parameter valueString: The value of the event as a string. The value must be a valid
     * number between -2^31 and 2^31 - 1 or it will invalidate the event.
     * - Returns: An Account event template instance
     */
    @objc(loggedOutTemplateWithValueFromString:)
    public class func loggedOutTemplate(valueString: String?) -> AccountEventTemplate {
        let decimalValue = valueString != nil ? NSDecimalNumber(string: valueString) : nil
        return loggedOutTemplate(value: decimalValue)
    }

    /**
     * Factory method for creating a logged out account event template with a value.
     *
     * - Parameter value: The value of the event. The value must be between -2^31 and
     * 2^31 - 1 or it will invalidate the event.
     * - Returns: An Account event template instance
     */
    @objc(loggedOutTemplateWithValue:)
    public class func loggedOutTemplate(value: NSNumber?) -> AccountEventTemplate {
        return AccountEventTemplate(eventName: "logged_out", value: value)
    }

    /**
     * Creates the custom account event.
     */
    @objc
    public func createEvent() -> CustomEvent? {
        var propertyDictionary: [String : Any] = [:]
        propertyDictionary["ltv"] = self.eventValue != nil
        propertyDictionary["user_id"] = self.userID
        propertyDictionary["category"] = self.category
        propertyDictionary["type"] = self.type

        let event = CustomEvent(name: self.eventName)
        event.templateType = "account"
        event.eventValue = self.eventValue
        event.transactionID = self.transactionID
        event.properties = propertyDictionary
        return event
    }
}
