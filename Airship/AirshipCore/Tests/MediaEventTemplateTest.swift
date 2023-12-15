/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipCore

final class MediaEventTemplateTest: XCTestCase {
    
    override func setUp() {
        super.setUp()
        
        let airship =  TestAirshipInstance()
        airship.components = [TestAnalytics()]
        airship.makeShared()
    }
    
    /**
     * Test basic browsedEvent.
     */
    func testBasicBrowsedEvent() {
        let event = MediaEventTemplate
            .browsedTemplate()
            .createEvent()
        
        XCTAssertEqual("browsed_content", event.data["event_name"] as? String, "Unexpected event name.")
        XCTAssertEqual(false, event.properties["ltv"] as? Bool, "Property ltv should be NO.")
        XCTAssertEqual("media", event.data["template_type"] as? String, "Unexpected event template type.")
    }
    
    /**
     * Test browsedEvent with optional properties.
     */
    func testBrowsedEventWithProperties() {
        let template = MediaEventTemplate.browsedTemplate()
        template.category = "media-category"
        template.identifier = "1234"
        template.eventDescription = "Browsed content media event."
        template.type = "audio type"
        template.author = "The Cool UA"
        template.isFeature = true
        template.publishedDate = "November 13, 2015"
        
        let event = template.createEvent()
        
        XCTAssertEqual("browsed_content", event.data["event_name"] as? String, "Unexpected event name.")
        XCTAssertEqual(false, event.properties["ltv"] as? Bool, "Property ltv should be NO.")
        XCTAssertEqual("media-category", event.properties["category"] as? String, "Unexpected category.")
        XCTAssertEqual("1234", event.properties["id"] as? String, "Unexpected ID.")
        XCTAssertEqual("Browsed content media event.", event.properties["description"] as? String, "Unexpected description.")
        XCTAssertEqual("audio type", event.properties["type"] as? String, "Unexpected type.")
        XCTAssertEqual("The Cool UA", event.properties["author"] as? String, "Unexpected author.")
        XCTAssertEqual(true, event.properties["feature"] as? Bool, "Unexpected feature.")
        XCTAssertEqual("November 13, 2015", event.properties["published_date"] as? String, "Unexpected published date.")
        XCTAssertEqual("media", event.data["template_type"] as? String, "Unexpected event template type.")
    }
    
    /**
     * Test basic starredEvent.
     */
    func testBasicStarredEvent() {
        let event = MediaEventTemplate.starredTemplate().createEvent()
        
        XCTAssertEqual("starred_content", event.data["event_name"] as? String, "Unexpected event name.")
        XCTAssertEqual(false, event.properties["ltv"] as? Bool, "Property ltv should be NO.")
        XCTAssertEqual("media", event.data["template_type"] as? String, "Unexpected event template type.")
    }
    
    /**
     * Test starredEvent with optional properties.
     */
    func testStarredEventWithProperties() {
        let template = MediaEventTemplate.starredTemplate()
        template.category = "media-category"
        template.identifier = "1234"
        template.eventDescription = "Starred content media event."
        template.type = "audio type"
        template.author = "The Cool UA"
        template.isFeature = true
        template.publishedDate = "November 13, 2015"

        let event = template.createEvent()

        XCTAssertEqual("starred_content", event.data["event_name"] as? String, "Unexpected event name.")
        XCTAssertEqual(false, event.properties["ltv"] as? Bool, "Property ltv should be NO.")
        XCTAssertEqual("media-category", event.properties["category"] as? String, "Unexpected category.")
        XCTAssertEqual("1234", event.properties["id"] as? String, "Unexpected ID.")
        XCTAssertEqual("Starred content media event.", event.properties["description"] as? String, "Unexpected description.")
        XCTAssertEqual("audio type", event.properties["type"] as? String, "Unexpected type.")
        XCTAssertEqual("The Cool UA", event.properties["author"] as? String, "Unexpected author.")
        XCTAssertEqual(true, event.properties["feature"] as? Bool, "Unexpected feature.")
        XCTAssertEqual("November 13, 2015", event.properties["published_date"] as? String, "Unexpected published date.")
        XCTAssertEqual("media", event.data["template_type"] as? String, "Unexpected event template type.")
    }
    
    /**
     * Test basic sharedEvent.
     */
    func testBasicSharedEvent() {
        let event = MediaEventTemplate.sharedTemplate().createEvent()
        
        XCTAssertEqual("shared_content", event.data["event_name"] as? String, "Unexpected event name.")
        XCTAssertEqual(false, event.properties["ltv"] as? Bool, "Property ltv should be NO.")
        XCTAssertEqual("media", event.data["template_type"] as? String, "Unexpected event template type.")
    }
    
    /**
     * Test sharedEvent with optional properties.
     */
    func testSharedEvent() {
        let template = MediaEventTemplate.sharedTemplate(source: "facebook", medium: "social")
        template.category = "media-category"
        template.identifier = "12345"
        template.eventDescription = "Shared content media event."
        template.type = "video type"
        template.author = "The Fun UA"
        template.isFeature = true
        template.publishedDate = "November 13, 2015"
        
        let event = template.createEvent()
        
        XCTAssertEqual("shared_content", event.data["event_name"] as? String, "Unexpected event name.")
        XCTAssertEqual(false, event.properties["ltv"] as? Bool, "Property ltv should be NO.")
        XCTAssertEqual("facebook", event.properties["source"] as? String, "Unexpected source.")
        XCTAssertEqual("social", event.properties["medium"] as? String, "Unexpected medium.")
        XCTAssertEqual("media-category", event.properties["category"] as? String, "Unexpected category.")
        XCTAssertEqual("12345", event.properties["id"] as? String, "Unexpected ID.")
        XCTAssertEqual("Shared content media event.", event.properties["description"] as? String, "Unexpected description.")
        XCTAssertEqual("video type", event.properties["type"] as? String, "Unexpected type.")
        XCTAssertEqual("The Fun UA", event.properties["author"] as? String, "Unexpected author.")
        XCTAssertEqual(true, event.properties["feature"] as? Bool, "Unexpected feature.")
        XCTAssertEqual("November 13, 2015", event.properties["published_date"] as? String, "Unexpected published date.")
        XCTAssertEqual("media", event.data["template_type"] as? String, "Unexpected event template type.")
    }
    
    /**
     * Test basic consumedEvent.
     */
    func testBasicConsumedEvent() {
        let event = MediaEventTemplate.consumedTemplate().createEvent()
        
        XCTAssertEqual("consumed_content", event.data["event_name"] as? String, "Unexpected event name.")
        XCTAssertEqual(false, event.properties["ltv"] as? Bool, "Property ltv should be NO.")
        XCTAssertEqual("media", event.data["template_type"] as? String, "Unexpected event template type.")
    }
    
    /**
     * Test consumedEvent with optional value from string.
     */
    func testConsumedEventWithValueFromString() {
        let event = MediaEventTemplate
            .consumedTemplate(valueString: "100.00")
            .createEvent()
        
        XCTAssertEqual("consumed_content", event.data["event_name"] as? String, "Unexpected event name.")
        XCTAssertEqual(100.00, event.eventValue, "Event value should be set from a valid numeric string.")
        XCTAssertEqual(true, event.properties["ltv"] as? Bool, "Unexpected ltv property.")
        XCTAssertEqual("media", event.data["template_type"] as? String, "Unexpected event template type.")
    }
    
    /**
     * Test consumedEvent with optional value and properties.
     */
    func testConsumedEventWithValueProperties() {
        let template = MediaEventTemplate.consumedTemplate(value: NSNumber(value: Int32.min))
        template.category = "media-category"
        template.identifier = "12322"
        template.eventDescription = "Consumed content media event."
        template.type = "audio type"
        template.author = "The Smart UA"
        template.isFeature = true
        template.publishedDate = "November 13, 2015"
        
        let event = template.createEvent()
        
        XCTAssertEqual("consumed_content", event.data["event_name"] as? String, "Unexpected event name.")
        XCTAssertEqual(-2147483648000000, event.data["event_value"] as? NSNumber, "Unexpected event value.")
        XCTAssertEqual(true, event.properties["ltv"] as? Bool, "Unexpected ltv property.")
        XCTAssertEqual("media-category", event.properties["category"] as? String, "Unexpected category.")
        XCTAssertEqual("12322", event.properties["id"] as? String, "Unexpected ID.")
        XCTAssertEqual("Consumed content media event.", event.properties["description"] as? String, "Unexpected description.")
        XCTAssertEqual("audio type", event.properties["type"] as? String, "Unexpected type.")
        XCTAssertEqual("The Smart UA", event.properties["author"] as? String, "Unexpected author.")
        XCTAssertEqual(true, event.properties["feature"] as? Bool, "Unexpected feature.")
        XCTAssertEqual("November 13, 2015", event.properties["published_date"] as? String, "Unexpected properties.")
        XCTAssertEqual("media", event.data["template_type"] as? String, "Unexpected event template type.")
    }
}
