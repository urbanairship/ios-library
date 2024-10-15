/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipCore

final class AccountEventTemplateTest: XCTestCase {
    
    @MainActor
    override func setUp() {
        super.setUp()
        
        let airship =  TestAirshipInstance()
        airship.components = [TestAnalytics()]
        airship.makeShared()
    }
    
    /**
     * Test basic registered account event with no optional value or properties.
     */
    func testBasicRegisteredAccountEvent() {
        let template = AccountEventTemplate.registeredTemplate()
        let event = template.createEvent()
        
        XCTAssertEqual("registered_account", event?.data["event_name"] as? String, "Unexpected event name.")
        XCTAssertEqual(false, event?.properties["ltv"] as? Bool, "Property ltv should be NO.")
        XCTAssertEqual("account", event?.data["template_type"] as? String, "Unexpected event template type.")
    }
    
    /**
     * Test registered account event with optional value from string.
     */
    func testRegisteredAccountEventWithValueFromString() {
        let template = AccountEventTemplate.registeredTemplate(valueString: "100.00")
        let event = template.createEvent()
        
        XCTAssertEqual("registered_account", event?.data["event_name"] as? String, "Unexpected event name.")
        XCTAssertEqual(100.00, event?.eventValue, "Event value should be set from a valid numeric string.")
        XCTAssertEqual(true, event?.properties["ltv"] as? Bool, "Unexpected ltv property.")
        XCTAssertEqual("account", event?.data["template_type"] as? String, "Unexpected event template type.")
    }
    
    /**
     * Test registered account event with optional value.
     */
    func testRegisteredAccountEventWithValue() {
        let template = AccountEventTemplate.registeredTemplate(value: NSNumber(value: Int32.min))
        let event = template.createEvent()
        
        XCTAssertEqual("registered_account", event?.data["event_name"] as? String, "Unexpected event name.")
        XCTAssertEqual(-2147483648000000, event?.data["event_value"] as? NSNumber, "Unexpected event value.")
        XCTAssertEqual(true, event?.properties["ltv"] as? Bool, "Unexpected ltv property.")
        XCTAssertEqual("account", event?.data["template_type"] as? String, "Unexpected event template type.")
    }
    
    /**
     * Test registered account event with optional value and properties.
     */
    func testRegisteredAccountEventWithValueProperties() {
        let template = AccountEventTemplate.registeredTemplate()
        template.eventValue = 12345.00
        template.transactionID = "1212"
        template.category = "premium"
        
        let event = template.createEvent()
        
        XCTAssertEqual("registered_account", event?.data["event_name"] as? String, "Unexpected event name.")
        XCTAssertEqual(12345, event?.eventValue, "Unexpected event value.")
        XCTAssertEqual(true, event?.properties["ltv"] as? Bool, "Unexpected ltv property.")
        XCTAssertEqual("1212", event?.transactionID, "Unexpected transaction ID.")
        XCTAssertEqual("premium", event?.properties["category"] as? String, "Unexpected category.")
        XCTAssertEqual("account", event?.data["template_type"] as? String, "Unexpected event template type.")
    }
    
    /**
     * Test basic logged in account event with no optional value or properties.
     */
    func testBasicLoggedInAccountEvent() {
        let event = AccountEventTemplate.loggedInTemplate().createEvent()
        
        XCTAssertEqual("logged_in", event?.data["event_name"] as? String, "Unexpected event name.")
        XCTAssertEqual(false, event?.properties["ltv"] as? Bool, "Property ltv should be NO.")
        XCTAssertEqual("account", event?.data["template_type"] as? String, "Unexpected event template type.")
    }
    
    /**
     * Test logged in account event with optional value from string.
     */
    func testLoggedInAccountEventWithValueFromString() {
        let event = AccountEventTemplate
            .loggedInTemplate(valueString: "100.00")
            .createEvent()
        
        XCTAssertEqual("logged_in", event?.data["event_name"] as? String, "Unexpected event name.")
        XCTAssertEqual(100.00, event?.eventValue, "Event value should be set from a valid numeric string.")
        XCTAssertEqual(true, event?.properties["ltv"] as? Bool, "Unexpected ltv property.")
        XCTAssertEqual("account", event?.data["template_type"] as? String, "Unexpected event template type.")
    }
    
    /**
     * Test logged in account event with optional value.
     */
    func testLoggedInAccountEventWithValue() {
        let event = AccountEventTemplate
            .loggedInTemplate(value: NSNumber(value: Int32.max))
            .createEvent()
        
        XCTAssertEqual("logged_in", event?.data["event_name"] as? String, "Unexpected event name.")
        XCTAssertEqual(2147483647000000, event?.data["event_value"] as? NSNumber, "Unexpected event value.")
        XCTAssertEqual(true, event?.properties["ltv"] as? Bool, "Unexpected ltv property.")
        XCTAssertEqual("account", event?.data["template_type"] as? String, "Unexpected event template type.")
    }
    
    /**
     * Test logged in account event with optional value and properties.
     */
    func testLoggedInAccountEventWithValueProperties() {
        let template = AccountEventTemplate.loggedInTemplate()
        template.eventValue = 12345.00
        template.transactionID = "1212"
        template.category = "Premium"
        template.userID = "FakeUserID"
        template.type = "FakeType"
        
        let event = template.createEvent()
        
        XCTAssertEqual("logged_in", event?.data["event_name"] as? String, "Unexpected event name.")
        XCTAssertEqual(12345, event?.eventValue, "Unexpected event value.")
        XCTAssertEqual(true, event?.properties["ltv"] as? Bool, "Unexpected ltv property.")
        XCTAssertEqual("1212", event?.transactionID, "Unexpected transaction ID.")
        XCTAssertEqual("Premium", event?.properties["category"] as? String, "Unexpected category.")
        XCTAssertEqual("account", event?.data["template_type"] as? String, "Unexpected event template type.")
        XCTAssertEqual("FakeUserID", event?.properties["user_id"] as? String, "Unexpected user ID.")
        XCTAssertEqual("FakeType", event?.properties["type"] as? String, "Unexpected type.")
    }
    
    /**
     * Test basic logged out account event with no optional value or properties.
     */
    func testBasicLoggedOutAccountEvent() {
        let event = AccountEventTemplate.loggedOutTemplate().createEvent()
        
        XCTAssertEqual("logged_out", event?.data["event_name"] as? String, "Unexpected event name.")
        XCTAssertEqual(false, event?.properties["ltv"] as? Bool, "Property ltv should be NO.")
        XCTAssertEqual("account", event?.data["template_type"] as? String, "Unexpected event template type.")
    }
    
    /**
     * Test logged out account event with optional value from string.
     */
    func testLoggedOutAccountEventWithValueFromString() {
        let event = AccountEventTemplate
            .loggedOutTemplate(valueString: "100.00")
            .createEvent()
        
        XCTAssertEqual("logged_out", event?.data["event_name"] as? String, "Unexpected event name.")
        XCTAssertEqual(100.00, event?.eventValue, "Event value should be set from a valid numeric string.")
        XCTAssertEqual(true, event?.properties["ltv"] as? Bool, "Unexpected ltv property.")
        XCTAssertEqual("account", event?.data["template_type"] as? String, "Unexpected event template type.")
    }
    
    /**
     * Test logged out account event with optional value.
     */
    func testLoggedOutAccountEventWithValue() {
        let event = AccountEventTemplate
            .loggedOutTemplate(value: NSNumber(value: Int32.min))
            .createEvent()
        
        XCTAssertEqual("logged_out", event?.data["event_name"] as? String, "Unexpected event name.")
        XCTAssertEqual(-2147483648000000, event?.data["event_value"] as? NSNumber, "Unexpected event value.")
        XCTAssertEqual(true, event?.properties["ltv"] as? Bool, "Unexpected ltv property.")
        XCTAssertEqual("account", event?.data["template_type"] as? String, "Unexpected event template type.")
    }
    
    /**
     * Test logged out account event with optional value and properties.
     */
    func testLoggedOutAccountEventWithValueProperties() {
        let template = AccountEventTemplate.loggedOutTemplate()
        template.eventValue = NSDecimalNumber(string: "12345.00")
        template.transactionID = "1212"
        template.category = "Premium"
        template.userID = "FakeUserID"
        template.type = "FakeType"
        
        let event = template.createEvent()
        
        XCTAssertEqual("logged_out", event?.data["event_name"] as? String, "Unexpected event name.")
        XCTAssertEqual(12345, event?.eventValue, "Unexpected event value.")
        XCTAssertEqual(true, event?.properties["ltv"] as? Bool, "Unexpected ltv property.")
        XCTAssertEqual("1212", event?.transactionID, "Unexpected transaction ID.")
        XCTAssertEqual("Premium", event?.properties["category"] as? String, "Unexpected category.")
        XCTAssertEqual("account", event?.data["template_type"] as? String, "Unexpected event template type.")
        XCTAssertEqual("FakeUserID", event?.properties["user_id"] as? String, "Unexpected user ID.")
        XCTAssertEqual("FakeType", event?.properties["type"] as? String, "Unexpected type.")
    }
}
