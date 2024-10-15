/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipCore

final class SearchEventTemplateTest: XCTestCase {
    
    @MainActor
    override func setUp() {
        super.setUp()
        
        let airship =  TestAirshipInstance()
        airship.components = [TestAnalytics()]
        airship.makeShared()
    }
    
    /**
     * Test basic search event.
     */
    func testBasicSearchEvent() {
        let template = SearchEventTemplate()
        let event = template.createEvent()
        
        let properties: [String: Any] = event.data["properties"] as! [String: Any]
        
        XCTAssertEqual("search", event.data["event_name"] as? String, "Unexpected event name.")
        XCTAssertEqual(false, properties["ltv"] as? Bool, "Property ltv should be NO.")
        XCTAssertEqual("search", event.data["template_type"] as? String, "Unexpected event template type.")
    }
    
    /**
     * Test search event with optional value.
     */
    func testSearchEventWithValue() {
        let template = SearchEventTemplate(value: NSNumber(value: Int8.min))
        let event = template.createEvent()
        
        let properties: [String: Any] = event.data["properties"] as! [String: Any]
        
        XCTAssertEqual("search", event.data["event_name"] as? String, "Unexpected event name.")
        XCTAssertEqual(NSNumber(value: -128000000), event.data["event_value"] as? NSNumber, "Unexpected event value.")
        XCTAssertEqual(true, properties["ltv"] as? Bool, "Unexpected ltv property.")
        XCTAssertEqual("search", event.data["template_type"] as? String, "Unexpected event template type.")
    }
    
    /**
     * Test search event with optional value and properties.
     */
    func testSearchEventWithValueProperties() {
        let template = SearchEventTemplate.template()
        template.eventValue = NSDecimalNumber(string: "12345.00")
        template.category = "search-category"
        template.query = "Sneakers"
        template.totalResults = 20
        
        let event = template.createEvent()
        let properties: [String: Any] = event.data["properties"] as! [String: Any]
        
        XCTAssertEqual("search", event.data["event_name"] as? String, "Unexpected event name.")
        XCTAssertEqual(12345, event.eventValue, "Unexpected event value.")
        XCTAssertEqual(true, properties["ltv"] as? Bool, "Unexpected ltv property.")
        XCTAssertEqual("search-category", properties["category"] as? String, "Unexpected category.")
        XCTAssertEqual("Sneakers", properties["query"] as? String, "Unexpected query.")
        XCTAssertEqual(20, properties["total_results"] as? Int, "Unexpected total results.")
        XCTAssertEqual("search", event.data["template_type"] as? String, "Unexpected event template type.")
    }
}
