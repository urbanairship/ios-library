/* Copyright Airship and Contributors */

public import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

@objc
public class UACustomEventSearchTemplate: NSObject {

    fileprivate var template: CustomEvent.SearchTemplate

    private init(template: CustomEvent.SearchTemplate) {
        self.template = template
    }

    @objc
    public static func search() -> UACustomEventSearchTemplate {
        return UACustomEventSearchTemplate(template: .search)
    }
}

@objc
public class UACustomEventSearchProperties: NSObject {

    /// The event's ID.
    @objc
    public var id: String?

    /// The search query.
    @objc
    public var query: String?

    /// The total search results
    @objc
    public var totalResults: NSNumber?

    /// The event's category.
    @objc
    public var category: String?

    /// The event's type.
    @objc
    public var type: String?

    /// If the value is a lifetime value or not.
    @objc
    public var isLTV: Bool

    @objc
    public init(id: String? = nil, query: String? = nil, totalResults: NSNumber? = nil, category: String? = nil, type: String? = nil, isLTV: Bool = false) {
        self.id = id
        self.query = query
        self.totalResults = totalResults
        self.category = category
        self.type = type
        self.isLTV = isLTV
    }

    fileprivate var properties: CustomEvent.SearchProperties {
        CustomEvent.SearchProperties(
            id: self.id,
            category: self.category,
            type: self.type,
            isLTV: self.isLTV,
            query: self.query,
            totalResults: self.totalResults?.intValue
        )
    }
}

@objc
public extension UACustomEvent {
    @objc
    convenience init(searchTemplate: UACustomEventSearchTemplate) {
        let customEvent = CustomEvent(searchTemplate: searchTemplate.template)
        self.init(event: customEvent)
    }

    @objc
    convenience init(searchTemplate: UACustomEventSearchTemplate, properties: UACustomEventSearchProperties) {
        let customEvent = CustomEvent(
            searchTemplate: searchTemplate.template,
            properties: properties.properties
        )
        self.init(event: customEvent)
    }
}
