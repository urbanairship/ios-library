/* Copyright Airship and Contributors */

/**
 * A UASearchEventTemplate represents a custom search event template for the
 * application.
 */
@objc
public class UASearchEventTemplate : NSObject {
    /**
     * The event's value. The value must be between -2^31 and
     * 2^31 - 1 or it will invalidate the event.
     */
    @objc
    public var eventValue: NSNumber?

    /**
     * The event's type.
     */
    @objc
    public var type: String?

    /**
     * The event's identifier.
     */
    @objc
    public var identifier: String?


    /**
     * The event's category.
     */
    @objc
    public var category: String?

    /**
     * The event's query.
     */
    @objc
    public var query: String?

    /**
     * The event's total results.
     */
    @objc
    public var totalResults: Int = 0


    /**
     * Default constructor.
     *
     * @param value The value of the event. The value must be between -2^31 and
     * 2^31 - 1 or it will invalidate the event.
     */
    public init(value: NSNumber? = nil) {
        super.init()
        self.eventValue = value
    }

    /**
     * Factory method for creating a search event template with a value.
     *
     * @param value The value of the event. The value must be between -2^31 and
     * 2^31 - 1 or it will invalidate the event.
     * @return UASearchEventTemplate instance.
     */
    @objc(templateWithValue:)
    public class func template(value: NSNumber) -> UASearchEventTemplate {
        return UASearchEventTemplate(value: value)
    }

    /**
     * Factory method for creating a search event template.
     * @return UASearchEventTemplate instance.
     */
    @objc(template)
    public class func template() -> UASearchEventTemplate {
        return UASearchEventTemplate()
    }

    /**
     * Creates the custom search event.
     * @return Created UACustomEvent instance.
     */
    @objc
    public func createEvent() -> UACustomEvent {
        var propertyDictionary: [String : Any] = [:]
        propertyDictionary["ltv"] = self.eventValue != nil
        propertyDictionary["id"] = identifier
        propertyDictionary["category"] = category
        propertyDictionary["query"] = query
        propertyDictionary["type"] = type
        propertyDictionary["total_results"] = self.totalResults > 0 ? self.totalResults : nil

        let event = UACustomEvent(name: "search")
        event.eventValue = self.eventValue
        event.templateType = "search"
        event.properties = propertyDictionary
        return event
    }
}
