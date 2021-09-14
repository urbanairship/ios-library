/* Copyright Airship and Contributors */

/**
 * A SearchEventTemplate represents a custom search event template for the
 * application.
 */
@objc(SearchEventTemplate)
public class SearchEventTemplate : NSObject {
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
     * - Parameter value: The value of the event. The value must be between -2^31 and
     * 2^31 - 1 or it will invalidate the event.
     */
    public init(value: NSNumber? = nil) {
        super.init()
        self.eventValue = value
    }

    /**
     * Factory method for creating a search event template with a value.
     *
     * - Parameter value: The value of the event. The value must be between -2^31 and
     * 2^31 - 1 or it will invalidate the event.
     * - Returns: SearchEventTemplate instance.
     */
    @objc(templateWithValue:)
    public class func template(value: NSNumber) -> SearchEventTemplate {
        return SearchEventTemplate(value: value)
    }

    /**
     * Factory method for creating a search event template.
     * - Returns: SearchEventTemplate instance.
     */
    @objc(template)
    public class func template() -> SearchEventTemplate {
        return SearchEventTemplate()
    }

    /**
     * Creates the custom search event.
     * - Returns: Created UACustomEvent instance.
     */
    @objc
    public func createEvent() -> CustomEvent {
        var propertyDictionary: [String : Any] = [:]
        propertyDictionary["ltv"] = self.eventValue != nil
        propertyDictionary["id"] = identifier
        propertyDictionary["category"] = category
        propertyDictionary["query"] = query
        propertyDictionary["type"] = type
        propertyDictionary["total_results"] = self.totalResults > 0 ? self.totalResults : nil

        let event = CustomEvent(name: "search")
        event.eventValue = self.eventValue
        event.templateType = "search"
        event.properties = propertyDictionary
        return event
    }
}
