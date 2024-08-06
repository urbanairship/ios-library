/* Copyright Airship and Contributors */

import Foundation
import AirshipCore

/// This singleton provides an interface to the functionality provided by the Airship iOS Push API.
@objc(OUASearchEventTemplate)
public class OUASearchEventTemplate: NSObject {
    
    private var template: SearchEventTemplate
    
    /**
     * The event's value. The value must be between -2^31 and
     * 2^31 - 1 or it will invalidate the event.
     */
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

    /**
     * The event's identifier.
     */
    @objc
    public var identifier: String? {
        get {
           return template.identifier
        }
        set {
            template.identifier = newValue
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
     * The event's query.
     */
    @objc
    public var query: String? {
        get {
           return template.query
        }
        set {
            template.query = newValue
        }
    }

    /**
     * The event's total results.
     */
    @objc
    public var totalResults: Int {
        get {
           return template.totalResults
        }
        set {
            template.totalResults = newValue
        }
    }

    @objc
    public init(template: SearchEventTemplate) {
        self.template = template
    }
    
    /**
     * Default constructor.
     *
     * - Parameter value: The value of the event. The value must be between -2^31 and
     * 2^31 - 1 or it will invalidate the event.
     */
    public convenience init(value: NSNumber? = nil) {
        let template = SearchEventTemplate(value: value)
        self.init(template: template)
    }

    /**
     * Factory method for creating a search event template with a value.
     *
     * - Parameter value: The value of the event. The value must be between -2^31 and
     * 2^31 - 1 or it will invalidate the event.
     * - Returns: SearchEventTemplate instance.
     */
    @objc(templateWithValue:)
    public class func template(value: NSNumber) -> OUASearchEventTemplate {
        let template = SearchEventTemplate(value: value)
        return OUASearchEventTemplate(template: template)
    }

    /**
     * Factory method for creating a search event template.
     * - Returns: SearchEventTemplate instance.
     */
    @objc(template)
    public class func template() -> OUASearchEventTemplate {
        let template = SearchEventTemplate()
        return OUASearchEventTemplate(template: template)
    }

    /**
     * Creates the custom search event.
     * - Returns: Created UACustomEvent instance.
     */
    @objc
    public func createEvent() -> CustomEvent {
        return self.template.createEvent()
    }
}
