/* Copyright Airship and Contributors */

import Foundation
public import AirshipCore

/// This singleton provides an interface to the functionality provided by the Airship iOS Push API.
@objc
public class UAMediaEventTemplate: NSObject {
    
    private var template: MediaEventTemplate
    
    /**
     * The event's ID.
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
     * The event's description.
     */
    @objc
    public var eventDescription: String? {
        get {
           return template.eventDescription
        }
        set {
            template.eventDescription = newValue
        }
    }

    /**
     * `YES` if the event is a feature, else `NO`.
     */
    @objc
    public var isFeature: Bool {
        get {
            return template.isFeature
        }
        set {
            template.isFeature = newValue
        }
    }

    /**
     * The event's author. The author's length must not exceed 255 characters
     * or it will invalidate the event.
     */
    @objc
    public var author: String? {
        get {
           return template.author
        }
        set {
            template.author = newValue
        }
    }

    /**
     * The event's publishedDate. The publishedDate's length must not exceed 255 characters
     * or it will invalidate the event.
     */
    @objc
    public var publishedDate: String? {
        get {
           return template.publishedDate
        }
        set {
            template.publishedDate = newValue
        }
    }
    
    @objc
    public init(template: MediaEventTemplate) {
        self.template = template
    }

    /**
     * Factory method for creating a browsed content event template.
     * - Returns: A Media event template instance
     */
    @objc
    public class func browsedTemplate() -> UAMediaEventTemplate {
        let template = MediaEventTemplate("browsed_content")
        return UAMediaEventTemplate(template: template)
    }

    /**
     * Factory method for creating a starred content event template.
     * - Returns: A Media event template instance
     */
    @objc
    public class func starredTemplate() -> UAMediaEventTemplate {
        let template = MediaEventTemplate("starred_content")
        return UAMediaEventTemplate(template: template)
    }

    /**
     * Factory method for creating a shared content event template.
     * - Returns: A Media event template instance
     */
    @objc
    public class func sharedTemplate() -> UAMediaEventTemplate {
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
    public class func sharedTemplate(source: String?, medium: String?)
        -> UAMediaEventTemplate
    {
        let template = MediaEventTemplate(
            "shared_content",
            value: nil,
            source: source,
            medium: medium
        )
        return UAMediaEventTemplate(template: template)
    }

    /**
     * Factory method for creating a consumed content event template.
     * - Returns: A Media event template instance
     */
    @objc
    public class func consumedTemplate() -> UAMediaEventTemplate {
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
    public class func consumedTemplate(valueString: String?)
        -> UAMediaEventTemplate
    {
        let decimalValue =
            valueString != nil ? NSDecimalNumber(string: valueString) : nil
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
    public class func consumedTemplate(value: NSNumber?) -> UAMediaEventTemplate {
        let template = MediaEventTemplate("consumed_content", value: value)
        return UAMediaEventTemplate(template: template)
    }

    /**
     * Creates the custom media event.
     */
    @objc
    public func createEvent() -> CustomEvent {
        return self.template.createEvent()
    }
}
