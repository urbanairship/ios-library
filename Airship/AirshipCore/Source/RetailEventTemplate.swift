/* Copyright Airship and Contributors */

import Foundation

/**
 * A RetailEventTemplate represents a custom retail event template for the
 * application.
 */
@objc(UARetailEventTemplate)
public class RetailEventTemplate: NSObject {

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
    public var transactionID: String?

    /**
     * The event's ID.
     */
    @objc
    public var identifier: String?

    /**
     * The event's category.
     */
    @objc
    public var category: String?

    /**
     * The event's description.
     */
    @objc
    public var eventDescription: String?

    /**
     * The brand..
     */
    @objc
    public var brand: String?

    /**
     * If the item is new or not.
     */
    @objc
    public var isNewItem : Bool {
        get {
            return self._isNewItem ?? false
        }
        set {
            self._isNewItem = newValue
        }
    }

    private var _isNewItem: Bool?
    private let eventName: String
    private let source: String?
    private let medium: String?
    private let wishlistName: String?
    private let wishlistID: String?

    /**
     * Factory method for creating a browsed event template.
     * - Returns: A Retail event template instance
     */
    @objc(browsedTemplate)
    public class func browsedTemplate() -> RetailEventTemplate {
        return browsedTemplate(value: nil)
    }

    /**
     * Factory method for creating a browsed event template with a value.
     *
     * - Parameter valueString: The value of the event as as string. The value must be between
     * -2^31 and 2^31 - 1 or it will invalidate the event.
     * - Returns: A Retail event template instance
     */
    @objc(browsedTemplateWithValueFromString:)
    public class func browsedTemplate(valueString: String?) -> RetailEventTemplate {
        let decimalValue = valueString != nil ? NSDecimalNumber(string: valueString) : nil
        return browsedTemplate(value: decimalValue)
    }

    /**
     * Factory method for creating a browsed event template with a value.
     *
     * - Parameter value: The value of the event. The value must be between -2^31 and
     * 2^31 - 1 or it will invalidate the event.
     * - Returns: A Retail event template instance
     */
    @objc(browsedTemplateWithValue:)
    public class func browsedTemplate(value: NSNumber?) -> RetailEventTemplate {
        return RetailEventTemplate("browsed", value: value)
    }

    /**
     * Factory method for creating an addedToCart event template.
     * - Returns: A Retail event template instance
     */
    @objc(addedToCartTemplate)
    public class func addedToCartTemplate() -> RetailEventTemplate {
        return addedToCartTemplate(value: nil)
    }

    /**
     * Factory method for creating an addedToCart event template with a value.
     *
     * - Parameter valueString: The value of the event as as string. The value must be between
     * -2^31 and 2^31 - 1 or it will invalidate the event.
     * - Returns: A Retail event template instance
     */
    @objc(addedToCartTemplateWithValueFromString:)
    public class func addedToCartTemplate(valueString: String?) -> RetailEventTemplate {
        let decimalValue = valueString != nil ? NSDecimalNumber(string: valueString) : nil
        return addedToCartTemplate(value: decimalValue)
    }

    /**
     * Factory method for creating an addedToCart event template with a value.
     *
     * - Parameter value: The value of the event. The value must be between -2^31 and
     * 2^31 - 1 or it will invalidate the event.
     * - Returns: A Retail event template instance
     */
    @objc(addedToCartTemplateWithValue:)
    public class func addedToCartTemplate(value: NSNumber?) -> RetailEventTemplate {
        return RetailEventTemplate("added_to_cart", value: value)
    }

    /**
     * Factory method for creating a starredProduct event template
     * - Returns: A Retail event template instance
     */
    @objc(starredProductTemplate)
    public class func starredProductTemplate() -> RetailEventTemplate {
        return starredProductTemplate(value: nil)
    }

    /**
     * Factory method for creating a starredProduct event template with a value.
     *
     * - Parameter valueString: The value of the event as as string. The value must be between
     * -2^31 and 2^31 - 1 or it will invalidate the event.
     * - Returns: A Retail event template instance
     */
    @objc(starredProductTemplateWithValueFromString:)
    public class func starredProductTemplate(valueString: String?) -> RetailEventTemplate {
        let decimalValue = valueString != nil ? NSDecimalNumber(string: valueString) : nil
        return starredProductTemplate(value: decimalValue)
    }

    /**
     * Factory method for creating a starredProduct event template with a value.
     *
     * - Parameter value: The value of the event. The value must be between -2^31 and
     * 2^31 - 1 or it will invalidate the event.
     * - Returns: A Retail event template instance
     */
    @objc(starredProductTemplateWithValue:)
    public class func starredProductTemplate(value: NSNumber?) -> RetailEventTemplate {
        return RetailEventTemplate("starred_product", value: value)
    }

    /**
     * Factory method for creating a purchased event template.
     * - Returns: A Retail event template instance
     */
    @objc(purchasedTemplate)
    public class func purchasedTemplate() -> RetailEventTemplate {
        return purchasedTemplate(value: nil)
    }

    /**
     * Factory method for creating a purchased event template with a value.
     *
     * - Parameter valueString: The value of the event as as string. The value must be between
     * -2^31 and 2^31 - 1 or it will invalidate the event.
     * - Returns: A Retail event template instance
     */
    @objc(purchasedTemplateWithValueFromString:)
    public class func purchasedTemplate(valueString: String?) -> RetailEventTemplate {
        let decimalValue = valueString != nil ? NSDecimalNumber(string: valueString) : nil
        return purchasedTemplate(value: decimalValue)
    }

    /**
     * Factory method for creating a purchased event template with a value.
     *
     * - Parameter value: The value of the event. The value must be between -2^31 and
     * 2^31 - 1 or it will invalidate the event.
     * - Returns: A Retail event template instance
     */
    @objc(purchasedTemplateWithValue:)
    public class func purchasedTemplate(value: NSNumber?) -> RetailEventTemplate {
        return RetailEventTemplate("purchased", value: value)
    }

    /**
     * Factory method for creating a sharedProduct template event.
     * - Returns: A Retail event template instance
     */
    @objc(sharedProductTemplate)
    public class func sharedProductTemplate() -> RetailEventTemplate {
        return sharedProductTemplate(value: nil, source: nil, medium: nil)
    }

    /**
     * Factory method for creating a sharedProduct event template with a value.
     *
     * - Parameter valueString: The value of the event as as string. The value must be between
     * -2^31 and 2^31 - 1 or it will invalidate the event.
     * - Returns: A Retail event template instance
     */
    @objc(sharedProductTemplateWithValueFromString:)
    public class func sharedProductTemplate(valueString: String?) -> RetailEventTemplate {
        let decimalValue = valueString != nil ? NSDecimalNumber(string: valueString) : nil
        return sharedProductTemplate(value: decimalValue, source: nil, medium: nil)
    }

    /**
     * Factory method for creating a sharedProduct event template with a value.
     *
     * - Parameter value: The value of the event. The value must be between -2^31 and
     * 2^31 - 1 or it will invalidate the event.
     * - Returns: A Retail event template instance
     */
    @objc(sharedProductTemplateWithValue:)
    public class func sharedProductTemplate(value: NSNumber?) -> RetailEventTemplate {
        return sharedProductTemplate(value: value, source: nil, medium: nil)
    }

    /**
     * Factory method for creating a sharedProduct event template.
     * - Parameter source: The source as an NSString.
     * - Parameter medium: The medium as an NSString
     * - Returns: A Retail event template instance.
     */
    @objc(sharedProductTemplateWithSource:withMedium:)
    public class func sharedProductTemplate(source: String?, medium: String?) -> RetailEventTemplate {
        return sharedProductTemplate(value: nil, source: source, medium: medium)
    }

    /**
     * Factory method for creating a sharedProduct event template with a value.
     *
     * - Parameter valueString: The value of the event as as string. The value must be between
     * -2^31 and 2^31 - 1 or it will invalidate the event.
     * - Parameter source: The source as an NSString.
     * - Parameter medium: The medium as an NSString.
     * - Returns: A Retail event template instance
     */
    @objc(sharedProductTemplateWithValueFromString:withSource:withMedium:)
    public class func sharedProductTemplate(valueString: String?, source: String?, medium: String?) -> RetailEventTemplate {
        let decimalValue = valueString != nil ? NSDecimalNumber(string: valueString) : nil
        return sharedProductTemplate(value: decimalValue, source: source, medium: medium)
    }

    /**
     * Factory method for creating a sharedProduct event template with a value.
     *
     * - Parameter value: The value of the event. The value must be between -2^31 and
     * 2^31 - 1 or it will invalidate the event.
     * - Parameter source: The source as an NSString.
     * - Parameter medium: The medium as an NSString.
     * - Returns: A Retail event template instance
     */
    @objc(sharedProductTemplateWithValue:withSource:withMedium:)
    public class func sharedProductTemplate(value: NSNumber?, source: String?, medium: String?) -> RetailEventTemplate {
        return RetailEventTemplate("shared_product", value: value, source: source, medium: medium)
    }

    /**
     * Factory method for creating a wishlist event template.
     * - Returns: A Retail event template instance
     */
    @objc(wishlistTemplate)
    public class func wishlistTemplate() -> RetailEventTemplate {
        return wishlistTemplate(name: nil, wishlistID: nil)
    }


    /**
     * Factory method for creating a wishlist event template with a wishlist name and ID.
     *
     * - Parameter name: The name of the wishlist as as string.
     * - Parameter wishlistID: The ID of the wishlist as as string.
     * - Returns: A Retail event template instance
     */
    @objc(wishlistTemplateWithName:wishlistID:)
    public class func wishlistTemplate(name: String?, wishlistID: String?) -> RetailEventTemplate {
        return RetailEventTemplate("wishlist", wishlistName: name, wishlistID: wishlistID)
    }

    private init(_ eventName: String, value: NSNumber? = nil, source: String? = nil, medium: String? = nil, wishlistName: String? = nil, wishlistID: String? = nil) {
        self.eventName = eventName
        self.eventValue = value
        self.source = source
        self.medium = medium
        self.wishlistID = wishlistID
        self.wishlistName = wishlistName
        super.init()
    }

    /**
     * Creates the custom media event.
     */
    @objc
    public func createEvent() -> CustomEvent {
        var propertyDictionary: [String : Any] = [:]
        propertyDictionary["ltv"] = self.eventName == "purchased" && self.eventValue != nil
        propertyDictionary["id"] = self.identifier
        propertyDictionary["category"] = self.category
        propertyDictionary["brand"] = self.brand
        propertyDictionary["new_item"] = self._isNewItem
        propertyDictionary["source"] = self.source
        propertyDictionary["medium"] = self.medium
        propertyDictionary["wishlist_name"] = self.wishlistName
        propertyDictionary["wishlist_id"] = self.wishlistID
        propertyDictionary["description"] = self.eventDescription

        let event = CustomEvent(name: self.eventName)
        event.templateType = "retail"
        event.eventValue = self.eventValue
        event.transactionID = self.transactionID
        event.properties = propertyDictionary
        return event
    }
}
