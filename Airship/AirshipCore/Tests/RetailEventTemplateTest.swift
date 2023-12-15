/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipCore

final class RetailEventTemplateTest: XCTestCase {
    
    override func setUp() {
        super.setUp()
        
        let airship =  TestAirshipInstance()
        airship.components = [TestAnalytics()]
        airship.makeShared()
    }
    
    /**
     * Test basic browsed event.
     */
    func testBasicBrowsedEvent() {
        let event = RetailEventTemplate
            .browsedTemplate()
            .createEvent()
        
        XCTAssertEqual("browsed", event.data["event_name"] as? String, "Unexpected event name.")
        XCTAssertEqual(false, event.properties["ltv"] as? Bool, "Unexpected ltv property.")
        XCTAssertEqual("retail", event.data["template_type"] as? String, "Unexpected event template type.")
    }
    
    /**
     * Test browsed event with value.
     */
    func testBrowsedEventWithValue() {
        let event = RetailEventTemplate
            .browsedTemplate(value: NSNumber(value: Int32.min))
            .createEvent()
        
        XCTAssertEqual("browsed", event.data["event_name"] as? String, "Unexpected event name.")
        XCTAssertEqual(-2147483648000000, event.data["event_value"] as? NSNumber, "Unexpected event value.")
        XCTAssertEqual(false, event.properties["ltv"] as? Bool, "Unexpected ltv property.")
        XCTAssertEqual("retail", event.data["template_type"] as? String, "Unexpected event template type.")
    }
    
    /**
     * Test browsed event with value from string and properties.
     */
    func testBrowsedEventWithValueStringProperties() {
        let template = RetailEventTemplate.browsedTemplate(valueString: "100.00")
        template.category = "retail-category"
        template.identifier = "12345"
        template.eventDescription = "Browsed retail event."
        template.transactionID = "1122334455"
        template.brand = "Airship"
        template.isNewItem = true
        
        let event = template.createEvent()
        
        XCTAssertEqual("browsed", event.data["event_name"] as? String, "Unexpected event name.")
        XCTAssertEqual(100.00, event.eventValue, "Event value should be set from a valid numeric string.")
        XCTAssertEqual(false, event.properties["ltv"] as? Bool, "Unexpected ltv property.")
        XCTAssertEqual("1122334455", event.transactionID, "Unexpected transaction ID.")
        XCTAssertEqual("retail-category", event.properties["category"] as? String, "Unexpected category.")
        XCTAssertEqual("12345", event.properties["id"] as? String, "Unexpected ID.")
        XCTAssertEqual("Browsed retail event.", event.properties["description"] as? String, "Unexpected description.")
        XCTAssertEqual("Airship", event.properties["brand"] as? String, "Unexpected category.")
        XCTAssertEqual(true, event.properties["new_item"] as? Bool, "Unexpected new item value.")
        XCTAssertEqual("retail", event.data["template_type"] as? String, "Unexpected event template type.")
    }
    
    /**
     * Test added to cart event.
     */
    func testAddedToCartEvent() {
        let event = RetailEventTemplate.addedToCartTemplate().createEvent()
        
        XCTAssertEqual("added_to_cart", event.data["event_name"] as? String, "Unexpected event name.")
        XCTAssertEqual(false, event.properties["ltv"] as? Bool, "Unexpected ltv property.")
        XCTAssertEqual("retail", event.data["template_type"] as? String, "Unexpected event template type.")
    }
    
    /**
     * Test added to cart event with value.
     */
    func testAddedToCartEventWithValue() {
        let event = RetailEventTemplate
            .addedToCartTemplate(value: NSNumber(value: Int32.min))
            .createEvent()
        
        XCTAssertEqual("added_to_cart", event.data["event_name"] as? String, "Unexpected event name.")
        XCTAssertEqual(-2147483648000000, event.data["event_value"] as? NSNumber, "Unexpected event value.")
        XCTAssertEqual(false, event.properties["ltv"] as? Bool, "Unexpected ltv property.")
        XCTAssertEqual("retail", event.data["template_type"] as? String, "Unexpected event template type.")
    }
    
    /**
     * Test added to cart event with value from string and properties.
     */
    func testAddedToCartEventWithValueStringProperties() {
        let template = RetailEventTemplate.addedToCartTemplate(valueString: "100.00")
        template.category = "retail-category"
        template.identifier = "12345"
        template.eventDescription = "Added to cart retail event."
        template.transactionID = "1122334455"
        template.brand = "Airship"
        template.isNewItem = true
        
        let event = template.createEvent()
        
        XCTAssertEqual("added_to_cart", event.data["event_name"] as? String, "Unexpected event name.")
        XCTAssertEqual(100.00, event.eventValue, "Event value should be set from a valid numeric string.")
        XCTAssertEqual(false, event.properties["ltv"] as? Bool, "Unexpected ltv property.")
        XCTAssertEqual("1122334455", event.transactionID, "Unexpected transaction ID.")
        XCTAssertEqual("retail-category", event.properties["category"] as? String, "Unexpected category.")
        XCTAssertEqual("12345", event.properties["id"] as? String, "Unexpected ID.")
        XCTAssertEqual("Added to cart retail event.", event.properties["description"] as? String, "Unexpected description.")
        XCTAssertEqual("Airship", event.properties["brand"] as? String, "Unexpected category.")
        XCTAssertEqual(true, event.properties["new_item"] as? Bool, "Unexpected new item value.")
        XCTAssertEqual("retail", event.data["template_type"] as? String, "Unexpected event template type.")
    }
    
    /**
     * Test starred product event.
     */
    func testStarredProductEvent() {
        let event = RetailEventTemplate
            .starredProductTemplate()
            .createEvent()
        
        XCTAssertEqual("starred_product", event.data["event_name"] as? String, "Unexpected event name.")
        XCTAssertEqual(false, event.properties["ltv"] as? Bool, "Unexpected ltv property.")
        XCTAssertEqual("retail", event.data["template_type"] as? String, "Unexpected event template type.")
    }
    
    /**
     * Test starred product event with value.
     */
    func testStarredProductEventWithValue() {
        let event = RetailEventTemplate
            .starredProductTemplate(value: NSNumber(value: Int32.min))
            .createEvent()
        
        XCTAssertEqual("starred_product", event.data["event_name"] as? String, "Unexpected event name.")
        XCTAssertEqual(-2147483648000000, event.data["event_value"] as? NSNumber, "Unexpected event value.")
        XCTAssertEqual(false, event.properties["ltv"] as? Bool, "Unexpected ltv property.")
        XCTAssertEqual("retail", event.data["template_type"] as? String, "Unexpected event template type.")
    }
    
    /**
     * Test starred product event with value from string and properties.
     */
    func testStarredProductEventWithValueStringProperties() {
        let template = RetailEventTemplate.starredProductTemplate(valueString: "100.00")
        template.category = "retail-category"
        template.identifier = "12345"
        template.eventDescription = "Starred product retail event."
        template.transactionID = "1122334455"
        template.brand = "Airship"
        template.isNewItem = true
        
        let event = template.createEvent()
        
        XCTAssertEqual("starred_product", event.data["event_name"] as? String, "Unexpected event name.")
        XCTAssertEqual(100.00, event.eventValue, "Event value should be set from a valid numeric string.")
        XCTAssertEqual(false, event.properties["ltv"] as? Bool, "Unexpected ltv property.")
        XCTAssertEqual("1122334455", event.transactionID, "Unexpected transaction ID.")
        XCTAssertEqual("retail-category", event.properties["category"] as? String, "Unexpected category.")
        XCTAssertEqual("12345", event.properties["id"] as? String, "Unexpected ID.")
        XCTAssertEqual("Starred product retail event.", event.properties["description"] as? String, "Unexpected description.")
        XCTAssertEqual("Airship", event.properties["brand"] as? String, "Unexpected category.")
        XCTAssertEqual(true, event.properties["new_item"] as? Bool, "Unexpected new item value.")
        XCTAssertEqual("retail", event.data["template_type"] as? String, "Unexpected event template type.")
    }
    
    /**
     * Test purchased event.
     */
    func testPurchasedEvent() {
        let event = RetailEventTemplate
            .purchasedTemplate()
            .createEvent()
        
        XCTAssertEqual("purchased", event.data["event_name"] as? String, "Unexpected event name.")
        XCTAssertEqual(false, event.properties["ltv"] as? Bool, "Unexpected ltv property.")
        XCTAssertEqual("retail", event.data["template_type"] as? String, "Unexpected event template type.")
    }
    
    /**
     * Test purchased event with value.
     */
    func testPurchasedEventWithValue() {
        let event = RetailEventTemplate
            .purchasedTemplate(value: NSNumber(value: Int32.min))
            .createEvent()
        
        XCTAssertEqual("purchased", event.data["event_name"] as? String, "Unexpected event name.")
        XCTAssertEqual(-2147483648000000, event.data["event_value"] as? NSNumber, "Unexpected event value.")
        XCTAssertEqual(true, event.properties["ltv"] as? Bool, "Unexpected ltv property.")
        XCTAssertEqual("retail", event.data["template_type"] as? String, "Unexpected event template type.")
    }
    
    /**
     * Test purchased event with value from string and properties.
     */
    func testPurchasedEventWithValueStringProperties() {
        let template = RetailEventTemplate.purchasedTemplate(valueString: "100.00")
        template.category = "retail-category"
        template.identifier = "12345"
        template.eventDescription = "Purchased retail event."
        template.transactionID = "1122334455"
        template.brand = "Airship"
        template.isNewItem = true
        
        let event = template.createEvent()
        
        XCTAssertEqual("purchased", event.data["event_name"] as? String, "Unexpected event name.")
        XCTAssertEqual(100.00, event.eventValue, "Event value should be set from a valid numeric string.")
        XCTAssertEqual(true, event.properties["ltv"] as? Bool, "Unexpected ltv property.")
        XCTAssertEqual("1122334455", event.transactionID, "Unexpected transaction ID.")
        XCTAssertEqual("retail-category", event.properties["category"] as? String, "Unexpected category.")
        XCTAssertEqual("12345", event.properties["id"] as? String, "Unexpected ID.")
        XCTAssertEqual("Purchased retail event.", event.properties["description"] as? String, "Unexpected description.")
        XCTAssertEqual("Airship", event.properties["brand"] as? String, "Unexpected category.")
        XCTAssertEqual(true, event.properties["new_item"] as? Bool, "Unexpected new item value.")
        XCTAssertEqual("retail", event.data["template_type"] as? String, "Unexpected event template type.")
    }
    
    /**
     * Test shared product event.
     */
    func testSharedProductEvent() {
        let event = RetailEventTemplate.sharedProductTemplate().createEvent()
        
        XCTAssertEqual("shared_product", event.data["event_name"] as? String, "Unexpected event name.")
        XCTAssertEqual(false, event.properties["ltv"] as? Bool, "Unexpected ltv property.")
        XCTAssertEqual("retail", event.data["template_type"] as? String, "Unexpected event template type.")
    }
    
    /**
     * Test shared product event with value.
     */
    func testSharedProductEventWithValue() {
        let event = RetailEventTemplate
            .sharedProductTemplate(value: NSNumber(value: Int32.min))
            .createEvent()
        
        XCTAssertEqual("shared_product", event.data["event_name"] as? String, "Unexpected event name.")
        XCTAssertEqual(-2147483648000000, event.data["event_value"] as? NSNumber, "Unexpected event value.")
        XCTAssertEqual(false, event.properties["ltv"] as? Bool, "Unexpected ltv property.")
        XCTAssertEqual("retail", event.data["template_type"] as? String, "Unexpected event template type.")
    }
    
    /**
     * Test shared product event with value from string and properties.
     */
    func testSharedProductEventWithValueStringProperties() {
        let template = RetailEventTemplate.sharedProductTemplate(valueString: "100.00")
        template.category = "retail-category"
        template.identifier = "12345"
        template.eventDescription = "Shared product retail event."
        template.transactionID = "1122334455"
        template.brand = "Airship"
        template.isNewItem = true
        
        let event = template.createEvent()
        
        XCTAssertEqual("shared_product", event.data["event_name"] as? String, "Unexpected event name.")
        XCTAssertEqual(100.00, event.eventValue, "Event value should be set from a valid numeric string.")
        XCTAssertEqual(false, event.properties["ltv"] as? Bool, "Unexpected ltv property.")
        XCTAssertEqual("1122334455", event.transactionID, "Unexpected transaction ID.")
        XCTAssertEqual("retail-category", event.properties["category"] as? String, "Unexpected category.")
        XCTAssertEqual("12345", event.properties["id"] as? String, "Unexpected ID.")
        XCTAssertEqual("Shared product retail event.", event.properties["description"] as? String, "Unexpected description.")
        XCTAssertEqual("Airship", event.properties["brand"] as? String, "Unexpected category.")
        XCTAssertEqual(true, event.properties["new_item"] as? Bool, "Unexpected new item value.")
        XCTAssertEqual("retail", event.data["template_type"] as? String, "Unexpected event template type.")
    }
    
    /**
     * Test shared product event with source and medium.
     */
    func testSharedProductEventSourceMedium() {
        let event = RetailEventTemplate
            .sharedProductTemplate(source: "facebook", medium: "social")
            .createEvent()
        
        XCTAssertEqual("shared_product", event.data["event_name"] as? String, "Unexpected event name.")
        XCTAssertEqual(false, event.properties["ltv"] as? Bool, "Unexpected ltv property.")
        XCTAssertEqual("facebook", event.properties["source"] as? String, "Unexpected source.")
        XCTAssertEqual("social", event.properties["medium"] as? String, "Unexpected medium.")
        XCTAssertEqual("retail", event.data["template_type"] as? String, "Unexpected event template type.")
    }
    
    /**
     * Test shared product event with value, source and medium.
     */
    func testSharedProductEventWithValueSourceMedium() {
        let event = RetailEventTemplate
            .sharedProductTemplate(value: NSNumber(value: Int32.min), source: "facebook", medium: "social")
            .createEvent()
        
        XCTAssertEqual("shared_product", event.data["event_name"] as? String, "Unexpected event name.")
        XCTAssertEqual(-2147483648000000, event.data["event_value"] as? NSNumber, "Unexpected event value.")
        XCTAssertEqual(false, event.properties["ltv"] as? Bool, "Unexpected ltv property.")
        XCTAssertEqual("facebook", event.properties["source"] as? String, "Unexpected source.")
        XCTAssertEqual("social", event.properties["medium"] as? String, "Unexpected medium.")
        XCTAssertEqual("retail", event.data["template_type"] as? String, "Unexpected event template type.")
    }
    
    /**
     * Test shared product event with value from string, source and medium.
     */
    func testSharedProductEventWithValueStringPropertiesSourceMedium() {
        let template = RetailEventTemplate.sharedProductTemplate(valueString: "100.00", source: "facebook", medium: "social")
        template.category = "retail-category"
        template.identifier = "12345"
        template.eventDescription = "Shared product retail event."
        template.transactionID = "1122334455"
        template.brand = "Airship"
        template.isNewItem = true
        
        let event = template.createEvent()
        
        XCTAssertEqual("shared_product", event.data["event_name"] as? String, "Unexpected event name.")
        XCTAssertEqual(100.00, event.eventValue, "Event value should be set from a valid numeric string.")
        XCTAssertEqual(false, event.properties["ltv"] as? Bool, "Unexpected ltv property.")
        XCTAssertEqual("1122334455", event.transactionID, "Unexpected transaction ID.")
        XCTAssertEqual("facebook", event.properties["source"] as? String, "Unexpected source.")
        XCTAssertEqual("social", event.properties["medium"] as? String, "Unexpected medium.")
        XCTAssertEqual("retail-category", event.properties["category"] as? String, "Unexpected category.")
        XCTAssertEqual("12345", event.properties["id"] as? String, "Unexpected ID.")
        XCTAssertEqual("Shared product retail event.", event.properties["description"] as? String, "Unexpected description.")
        XCTAssertEqual("Airship", event.properties["brand"] as? String, "Unexpected category.")
        XCTAssertEqual(true, event.properties["new_item"] as? Bool, "Unexpected new item value.")
        XCTAssertEqual("retail", event.data["template_type"] as? String, "Unexpected event template type.")
    }
    
    /**
     * Test wishlist event.
     */
    func testWishlistEvent() {
        let event = RetailEventTemplate.wishlistTemplate().createEvent()
        
        XCTAssertEqual("wishlist", event.data["event_name"] as? String, "Unexpected event name.")
        XCTAssertEqual(false, event.properties["ltv"] as? Bool, "Unexpected ltv property.")
        XCTAssertEqual("retail", event.data["template_type"] as? String, "Unexpected event template type.")
    }
    
    /**
     * Test wishlist event with wishlist name and ID.
     */
    func testWishlistEventWithNameAndID() {
        let event = RetailEventTemplate
            .wishlistTemplate(name: "wishlist_test", wishlistID: "1234")
            .createEvent()
        
        XCTAssertEqual("wishlist", event.data["event_name"] as? String, "Unexpected event name.")
        XCTAssertEqual("wishlist_test", event.properties["wishlist_name"] as? String, "Unexpected event wishlist name.")
        XCTAssertEqual("1234", event.properties["wishlist_id"] as? String, "Unexpected event wishlist ID.")
        XCTAssertEqual("retail", event.data["template_type"] as? String, "Unexpected event template type.")
    }
}
