/* Copyright Airship and Contributors */

/**
 * A MediaEventTemplate represents a custom media event template for the
 * application.
 */
@objc(UAMediaEventTemplate)
public class MediaEventTemplate : NSObject {
    /**
     * The event's ID.
     */
    @objc
    public var identifier : String?

    /**
     * The event's category.
     */
    @objc
    public var category : String?

    /**
     * The event's type.
     */
    @objc
    public var type : String?

    /**
     * The event's description.
     */
    @objc
    public var eventDescription : String?

    private var _isFeature: Bool?

    /**
     * `YES` if the event is a feature, else `NO`.
     */
    @objc
    public var isFeature : Bool {
        get {
            return self._isFeature ?? false
        }
        set {
            self._isFeature = newValue
        }
    }

    /**
     * The event's author. The author's length must not exceed 255 characters
     * or it will invalidate the event.
     */
    @objc
    public var author : String?

    /**
     * The event's publishedDate. The publishedDate's length must not exceed 255 characters
     * or it will invalidate the event.
     */
    @objc
    public var publishedDate : String?

    private let eventName: String
    private let medium: String?
    private let source: String?
    private let eventValue: NSNumber?

    /**
     * Factory method for creating a browsed content event template.
     * - Returns: A Media event template instance
     */
    @objc
    public class func browsedTemplate() -> MediaEventTemplate {
        return MediaEventTemplate("browsed_content")
    }


    /**
     * Factory method for creating a starred content event template.
     * - Returns: A Media event template instance
     */
    @objc
    public class func starredTemplate() -> MediaEventTemplate {
        return MediaEventTemplate("starred_content")

    }


    /**
     * Factory method for creating a shared content event template.
     * - Returns: A Media event template instance
     */
    @objc
    public class func sharedTemplate() -> MediaEventTemplate {
        return sharedTemplate(source: nil, medium: nil)
    }


    /**
     * Factory method for creating a shared content event template.
     * If the source or medium exceeds 255 characters it will cause the event to be invalid.
     *
     * - Parameter source: The source as an NSString.
     * - Parameter medium: The medium as an NSString.
     * - Returns: A Media event template instance
     */
    @objc(sharedTemplateWithSource:withMedium:)
    public class func sharedTemplate(source: String?, medium: String?) -> MediaEventTemplate {
        return MediaEventTemplate("shared_content", value: nil, source: source, medium: medium)
    }


    /**
     * Factory method for creating a consumed content event template.
     * - Returns: A Media event template instance
     */
    @objc
    public class func consumedTemplate() -> MediaEventTemplate {
        return consumedTemplate(value: nil)
    }


    /**
     * Factory method for creating a consumed content event template with a value.
     *
     * - Parameter valueString: The value of the event as as string. The value must be between
     * -2^31 and 2^31 - 1 or it will invalidate the event.
     * - Returns: A Media event template instance
     */
    @objc(consumedTemplateWithValueFromString:)
    public class func consumedTemplate(valueString: String?) -> MediaEventTemplate {
        let decimalValue = valueString != nil ? NSDecimalNumber(string: valueString) : nil
        return consumedTemplate(value: decimalValue)
    }


    /**
     * Factory method for creating a consumed content event template with a value.
     *
     * - Parameter value: The value of the event. The value must be between -2^31 and
     * 2^31 - 1 or it will invalidate the event.
     * - Returns: A Media event template instance
     */
    @objc(consumedTemplateWithValue:)
    public class func consumedTemplate(value: NSNumber?) -> MediaEventTemplate {
        return MediaEventTemplate("consumed_content", value: value)
    }

    private init(_ eventName: String, value: NSNumber? = nil, source: String? = nil, medium: String? = nil) {
        self.eventName = eventName
        self.eventValue = value
        self.source = source
        self.medium = medium
        super.init()
    }

    /**
     * Creates the custom media event.
     */
    @objc
    public func createEvent() -> CustomEvent {
        var propertyDictionary: [String : Any] = [:]
        propertyDictionary["ltv"] = self.eventValue != nil
        propertyDictionary["id"] = self.identifier
        propertyDictionary["category"] = self.category
        propertyDictionary["type"] = self.type
        propertyDictionary["feature"] = self.isFeature
        propertyDictionary["published_date"] = self.publishedDate
        propertyDictionary["source"] = self.source
        propertyDictionary["medium"] = self.medium
        propertyDictionary["description"] = self.eventDescription
        propertyDictionary["author"] = self.author

        let event = CustomEvent(name: self.eventName)
        event.templateType = "media"
        event.eventValue = self.eventValue
        event.properties = propertyDictionary
        return event
    }
}
