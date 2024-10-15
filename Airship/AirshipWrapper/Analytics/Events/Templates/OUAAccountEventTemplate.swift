/* Copyright Airship and Contributors */

import Foundation
public import AirshipCore

/// This singleton provides an interface to the functionality provided by the Airship iOS Push API.
@objc(OUAAccountEventTemplate)
public class OUAAccountEventTemplate: NSObject {
   
    private var template: AccountEventTemplate
    
    @objc
    public var eventValue: NSNumber? {
        get {
           return template.eventValue
        }
        set {
            template.eventValue = newValue
        }
    }

    /**
     * The event's transaction ID. The transaction ID's length must not exceed 255
     * characters or it will invalidate the event.
     */
    @objc
    public var transactionID: String? {
        get {
           return template.transactionID
        }
        set {
            template.transactionID = newValue
        }
    }

    /**
     * The event's identifier.
     */
    @objc
    public var userID: String? {
        get {
           return template.userID
        }
        set {
            template.userID = newValue
        }
    }

    /**
     * The event's category.
     */
    @objc
    public var category: String? {
        get {
           return template.category
        }
        set {
            template.category = newValue
        }
    }

    /**
     * The event's type.
     */
    @objc
    public var type: String? {
        get {
           return template.type
        }
        set {
            template.type = newValue
        }
    }
    
    @objc
    public init(template: AccountEventTemplate) {
        self.template = template
    }

    /**
     * Factory method for creating a registered account event template.
     * - Returns: An Account event template instance
     */
    @objc
    public class func registeredTemplate() -> OUAAccountEventTemplate {
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
    public class func registeredTemplate(valueString: String?)
        -> OUAAccountEventTemplate
    {
        let decimalValue =
            valueString != nil ? NSDecimalNumber(string: valueString) : nil
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
    public class func registeredTemplate(value: NSNumber?)
        -> OUAAccountEventTemplate
    {
        let template = AccountEventTemplate(
            eventName: "registered_account",
            value: value
        )
        return OUAAccountEventTemplate(template: template)
    }

    /**
     * Factory method for creating a logged in account event template.
     * - Returns: An Account event template instance
     */
    @objc
    public class func loggedInTemplate() -> OUAAccountEventTemplate {
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
    public class func loggedInTemplate(valueString: String?)
        -> OUAAccountEventTemplate
    {
        let decimalValue =
            valueString != nil ? NSDecimalNumber(string: valueString) : nil
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
    public class func loggedInTemplate(value: NSNumber?) -> OUAAccountEventTemplate
    {
        let template = AccountEventTemplate(eventName: "logged_in", value: value)
        return OUAAccountEventTemplate(template: template)
    }

    /**
     * Factory method for creating a logged out account event template.
     * - Returns: An Account event template instance
     */
    @objc
    public class func loggedOutTemplate() -> OUAAccountEventTemplate {
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
    public class func loggedOutTemplate(valueString: String?)
        -> OUAAccountEventTemplate
    {
        let decimalValue =
            valueString != nil ? NSDecimalNumber(string: valueString) : nil
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
    public class func loggedOutTemplate(value: NSNumber?)
        -> OUAAccountEventTemplate
    {
        let template = AccountEventTemplate(eventName: "logged_out", value: value)
        return OUAAccountEventTemplate(template: template)
    }

    /**
     * Creates the custom account event.
     */
    @objc
    public func createEvent() -> CustomEvent? {
        return self.template.createEvent()
    }
    
    
}
