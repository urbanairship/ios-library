/* Copyright Airship and Contributors */

public import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif


/// This singleton provides an interface to the functionality provided by the Airship iOS Push API.
@objc
public final class UACustomEventRetailTemplate: NSObject {

    fileprivate var template: CustomEvent.RetailTemplate

    private init(template: CustomEvent.RetailTemplate) {
        self.template = template
    }

    @objc
    public static func browsed() -> UACustomEventRetailTemplate {
        self.init(template: .browsed)
    }

    @objc
    public static func addedToCart() -> UACustomEventRetailTemplate {
        self.init(template: .addedToCart)
    }

    @objc
    public static func shared(source: String?, medium: String?) -> UACustomEventRetailTemplate {
        self.init(template: .shared(source: source, medium: medium))
    }

    @objc
    public static func starred() -> UACustomEventRetailTemplate {
        self.init(template: .starred)
    }

    @objc
    public static func purchased() -> UACustomEventRetailTemplate {
        self.init(template: .purchased)
    }

    @objc
    public static func wishlist(identifier: String?, name: String?) -> UACustomEventRetailTemplate {
        self.init(template: .wishlist(id: identifier, name: name))
    }
}

@objc
public class UACustomEventRetailProperties: NSObject {

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

    /// The brand.
    @objc
    public var brand: String?

    /// If its a new item or not.
    @objc
    public var isNewItem: NSNumber?

    /// The currency.
    @objc
    public var currency: String?

    /// If the value is a lifetime value or not.
    @objc
    public var isLTV: Bool

    @objc
    public init(id: String? = nil, category: String? = nil, type: String? = nil, eventDescription: String? = nil, isLTV: Bool = false, brand: String? = nil, isNewItem: NSNumber? = nil, currency: String? = nil) {
        self.id = id
        self.category = category
        self.type = type
        self.eventDescription = eventDescription
        self.isLTV = isLTV
        self.brand = brand
        self.isNewItem = isNewItem
        self.currency = currency
    }

    fileprivate var properties: CustomEvent.RetailProperties {
        return CustomEvent.RetailProperties(
            id: self.id,
            category: self.category,
            type: self.type,
            eventDescription: self.eventDescription,
            isLTV: self.isLTV,
            brand: self.brand,
            isNewItem: self.isNewItem?.boolValue,
            currency: self.currency
        )
    }
}

@objc
public extension UACustomEvent {
    @objc
    convenience init(retailTemplate: UACustomEventRetailTemplate) {
        let customEvent = CustomEvent(retailTemplate: retailTemplate.template)
        self.init(event: customEvent)
    }

    @objc
    convenience init(retailTemplate: UACustomEventRetailTemplate, properties: UACustomEventRetailProperties) {
        let customEvent = CustomEvent(
            retailTemplate: retailTemplate.template,
            properties: properties.properties
        )
        self.init(event: customEvent)
    }
}
