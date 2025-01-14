/* Copyright Airship and Contributors */

public import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Media template
@objc
public final class UACustomEventMediaTemplate: NSObject {

    fileprivate var template: CustomEvent.MediaTemplate

    private init(template: CustomEvent.MediaTemplate) {
        self.template = template
    }

    @objc
    public static func browsed() -> UACustomEventMediaTemplate {
        self.init(template: .browsed)
    }

    @objc
    public static func consumed() -> UACustomEventMediaTemplate {
        self.init(template: .consumed)
    }

    @objc
    public static func shared(source: String?, medium: String?) -> UACustomEventMediaTemplate {
        self.init(template: .shared(source: source, medium: medium))
    }

    @objc
    public static func starred() -> UACustomEventMediaTemplate {
        self.init(template: .starred)
    }
}

@objc
public class UACustomEventMediaProperties: NSObject {

    /// The event's ID.
    @objc
    public var id: String?

    /// The event's category.
    @objc
    public var category: String?

    /// The event's type.
    @objc
    public var type: String?

    /// The event's description.
    @objc
    public var eventDescription: String?

    /// The event's author.
    @objc
    public var author: String?

    /// The event's published date.
    @objc
    public var publishedDate: Date?

    /// If the event is a feature
    @objc
    public var isFeature: NSNumber?

    /// If the value is a lifetime value or not.
    @objc
    public var isLTV: Bool

    @objc
    public init(id: String? = nil, category: String? = nil, type: String? = nil, eventDescription: String? = nil, isLTV: Bool = false, author: String? = nil, publishedDate: Date? = nil, isFeature: NSNumber? = nil) {
        self.id = id
        self.category = category
        self.type = type
        self.eventDescription = eventDescription
        self.author = author
        self.publishedDate = publishedDate
        self.isFeature = isFeature
        self.isLTV = isLTV
    }

    fileprivate var properties: CustomEvent.MediaProperties {
        return CustomEvent.MediaProperties(
            id: self.id,
            category: self.category,
            type: self.type,
            eventDescription: self.eventDescription,
            isLTV: self.isLTV,
            author: self.author,
            publishedDate: self.publishedDate,
            isFeature: self.isFeature?.boolValue
        )
    }
}

@objc
public extension UACustomEvent {
    @objc
    convenience init(mediaTemplate: UACustomEventMediaTemplate) {
        let customEvent = CustomEvent(mediaTemplate: mediaTemplate.template)
        self.init(event: customEvent)
    }

    @objc
    convenience init(mediaTemplate: UACustomEventMediaTemplate, properties: UACustomEventMediaProperties) {
        let customEvent = CustomEvent(
            mediaTemplate: mediaTemplate.template,
            properties: properties.properties
        )
        self.init(event: customEvent)
    }
}
