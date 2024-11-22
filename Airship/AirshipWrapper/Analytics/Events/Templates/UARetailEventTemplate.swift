/* Copyright Airship and Contributors */

import Foundation
public import AirshipCore

/// This singleton provides an interface to the functionality provided by the Airship iOS Push API.
@objc
public class UARetailEventTemplate: NSObject {
    
    private var template: RetailEventTemplate
    
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
     * The brand..
     */
    @objc
    public var brand: String? {
        get {
           return template.brand
        }
        set {
            template.brand = newValue
        }
    }

    /**
     * If the item is new or not.
     */
    @objc
    public var isNewItem: Bool {
        get {
            return template.isNewItem
        }
        set {
            template.isNewItem = newValue
        }
    }
    
    @objc
    public init(template: RetailEventTemplate) {
        self.template = template
    }

    /**
     * Factory method for creating a browsed event template.
     * - Returns: A Retail event template instance
     */
    @objc(browsedTemplate)
    public class func browsedTemplate() -> UARetailEventTemplate {
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
    public class func browsedTemplate(valueString: String?)
        -> UARetailEventTemplate
    {
        let decimalValue =
            valueString != nil ? NSDecimalNumber(string: valueString) : nil
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
    public class func browsedTemplate(value: NSNumber?) -> UARetailEventTemplate {
        let template = RetailEventTemplate("browsed", value: value)
        return UARetailEventTemplate(template: template)
    }

    /**
     * Factory method for creating an addedToCart event template.
     * - Returns: A Retail event template instance
     */
    @objc(addedToCartTemplate)
    public class func addedToCartTemplate() -> UARetailEventTemplate {
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
    public class func addedToCartTemplate(valueString: String?)
        -> UARetailEventTemplate
    {
        let decimalValue =
            valueString != nil ? NSDecimalNumber(string: valueString) : nil
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
    public class func addedToCartTemplate(value: NSNumber?)
        -> UARetailEventTemplate
    {
        let template = RetailEventTemplate("added_to_cart", value: value)
        return UARetailEventTemplate(template: template)
    }

    /**
     * Factory method for creating a starredProduct event template
     * - Returns: A Retail event template instance
     */
    @objc(starredProductTemplate)
    public class func starredProductTemplate() -> UARetailEventTemplate {
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
    public class func starredProductTemplate(valueString: String?)
        -> UARetailEventTemplate
    {
        let decimalValue =
            valueString != nil ? NSDecimalNumber(string: valueString) : nil
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
    public class func starredProductTemplate(value: NSNumber?)
        -> UARetailEventTemplate
    {
        let template = RetailEventTemplate("starred_product", value: value)
        return UARetailEventTemplate(template: template)
    }

    /**
     * Factory method for creating a purchased event template.
     * - Returns: A Retail event template instance
     */
    @objc(purchasedTemplate)
    public class func purchasedTemplate() -> UARetailEventTemplate {
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
    public class func purchasedTemplate(valueString: String?)
        -> UARetailEventTemplate
    {
        let decimalValue =
            valueString != nil ? NSDecimalNumber(string: valueString) : nil
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
    public class func purchasedTemplate(value: NSNumber?) -> UARetailEventTemplate
    {
        let template = RetailEventTemplate("purchased", value: value)
        return UARetailEventTemplate(template: template)
    }

    /**
     * Factory method for creating a sharedProduct template event.
     * - Returns: A Retail event template instance
     */
    @objc(sharedProductTemplate)
    public class func sharedProductTemplate() -> UARetailEventTemplate {
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
    public class func sharedProductTemplate(valueString: String?)
        -> UARetailEventTemplate
    {
        let decimalValue =
            valueString != nil ? NSDecimalNumber(string: valueString) : nil
        return sharedProductTemplate(
            value: decimalValue,
            source: nil,
            medium: nil
        )
    }

    /**
     * Factory method for creating a sharedProduct event template with a value.
     *
     * - Parameter value: The value of the event. The value must be between -2^31 and
     * 2^31 - 1 or it will invalidate the event.
     * - Returns: A Retail event template instance
     */
    @objc(sharedProductTemplateWithValue:)
    public class func sharedProductTemplate(value: NSNumber?)
        -> UARetailEventTemplate
    {
        return sharedProductTemplate(value: value, source: nil, medium: nil)
    }

    /**
     * Factory method for creating a sharedProduct event template.
     * - Parameter source: The source as an NSString.
     * - Parameter medium: The medium as an NSString
     * - Returns: A Retail event template instance.
     */
    @objc(sharedProductTemplateWithSource:withMedium:)
    public class func sharedProductTemplate(source: String?, medium: String?)
        -> UARetailEventTemplate
    {
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
    public class func sharedProductTemplate(
        valueString: String?,
        source: String?,
        medium: String?
    ) -> UARetailEventTemplate {
        let decimalValue =
            valueString != nil ? NSDecimalNumber(string: valueString) : nil
        return sharedProductTemplate(
            value: decimalValue,
            source: source,
            medium: medium
        )
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
    public class func sharedProductTemplate(
        value: NSNumber?,
        source: String?,
        medium: String?
    ) -> UARetailEventTemplate {
        let template = RetailEventTemplate(
            "shared_product",
            value: value,
            source: source,
            medium: medium
        )
        return UARetailEventTemplate(template: template)
    }

    /**
     * Factory method for creating a wishlist event template.
     * - Returns: A Retail event template instance
     */
    @objc(wishlistTemplate)
    public class func wishlistTemplate() -> UARetailEventTemplate {
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
    public class func wishlistTemplate(name: String?, wishlistID: String?)
        -> UARetailEventTemplate
    {
        let template = RetailEventTemplate(
            "wishlist",
            wishlistName: name,
            wishlistID: wishlistID
        )
        return UARetailEventTemplate(template: template)
    }

    /**
     * Creates the custom media event.
     */
    @objc
    public func createEvent() -> CustomEvent {
        self.template.createEvent()
    }
    
}
