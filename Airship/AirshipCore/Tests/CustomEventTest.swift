/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipCore

final class CustomEventTest: XCTestCase {
    
    private let analytics = TestAnalytics()
    
    override func setUp() {
        super.setUp()
        
        let airship =  TestAirshipInstance()
        airship.components = [analytics]
        airship.makeShared()
    }
    
    /**
     * Test creating a custom event.
     */
    func testCustomEvent() {
        let eventName = "".padding(toLength: 255, withPad: "EVENT_NAME", startingAt: 0)
        let transactionId = "".padding(toLength: 255, withPad: "TRANSACTION_ID", startingAt: 0)
        let interactionId = "".padding(toLength: 255, withPad: "INTERACTION_ID", startingAt: 0)
        let interactionType = "".padding(toLength: 255, withPad: "INTERACTION_TYPE", startingAt: 0)
        let templateType = "".padding(toLength: 255, withPad: "TEMPLATE_TYPE", startingAt: 0)
        
        let event = CustomEvent(name: eventName, value: NSNumber(value: Int32.min))
        event.transactionID = transactionId
        event.interactionID = interactionId
        event.interactionType = interactionType
        event.templateType = templateType
        
        XCTAssertEqual(eventName, event.data["event_name"] as? String, "Unexpected event name.")
        XCTAssertEqual(transactionId, event.data["transaction_id"] as? String, "Unexpected transaction ID.")
        XCTAssertEqual(interactionId, event.data["interaction_id"] as? String, "Unexpected interaction ID.")
        XCTAssertEqual(interactionType, event.data["interaction_type"] as? String, "Unexpected interaction type.")
        XCTAssertEqual(templateType, event.data["template_type"] as? String, "Unexpected template type.")
        XCTAssertEqual(NSNumber(value: -2147483648000000), event.data["event_value"] as? NSNumber, "Unexpected event value.")
    }
    
    /**
     * Test setting an event name.
     */
    func testSetCustomEventName() {
        let event = CustomEvent(name: "event name")
        XCTAssert(event.isValid())
        
        let largeName = "".padding(toLength: 255, withPad: "event-name", startingAt: 0)
        event.eventName = largeName
        XCTAssert(event.isValid())
    }
    
    /**
     * Test setting the interaction ID.
     */
    func testSetInteractionID() {
        let event = CustomEvent(name: "event name")
        XCTAssertNil(event.interactionID, "Interaction ID should default to nil")
        
        let longInteractionId = "".padding(toLength: 255, withPad: "INTERACTION_ID", startingAt: 0)
        event.interactionID = longInteractionId
        XCTAssert(event.isValid())
        
        event.interactionID = nil
        XCTAssert(event.isValid())
    }
    
    /**
     * Test setting the interaction type.
     */
    func testSetInteractionType() {
        let event = CustomEvent(name: "event name")
        XCTAssertNil(event.interactionType, "Interaction type should default to nil")
        
        let longInteractionType = "".padding(toLength: 255, withPad: "INTERACTION_TYPE", startingAt: 0)
        event.interactionType = longInteractionType
        XCTAssert(event.isValid())
        
        event.interactionType = nil
        XCTAssert(event.isValid())
    }
    
    /**
     * Test setting the transaction ID
     */
    func testSetTransactionID() {
        let event = CustomEvent(name: "event name")
        XCTAssertNil(event.transactionID, "Transaction ID should default to nil")

        let longTransactionID = "".padding(toLength: 255, withPad: "TRANSACTION_ID", startingAt: 0)

        event.transactionID = longTransactionID
        XCTAssertTrue(event.isValid())

        event.transactionID = nil
        XCTAssertTrue(event.isValid())
    }
    
    /**
     * Test set template type
     */
    func testSetTemplateType() {
        let event = CustomEvent(name: "event name")
        XCTAssertNil(event.templateType, "Template type should default to nil")

        let longTemplateType = "".padding(toLength: 255, withPad: "TEMPLATE_TYPE", startingAt: 0)

        event.templateType = longTemplateType
        XCTAssertTrue(event.isValid())

        event.templateType = nil
        XCTAssertTrue(event.isValid())
    }
    
    /**
     * Test event value from a string.
     */
    func testSetEventValueString() {
        var event = CustomEvent(name: "event name", stringValue: "100.00")
        
        XCTAssertEqual(100.00, event.eventValue, "Event value should be set from a valid numeric string.")
        XCTAssertTrue(event.isValid())

        // Max value
        let maxValue = NSNumber(value: Int32.max)
        event = CustomEvent(name: "event name", stringValue: maxValue.stringValue)
        XCTAssertEqual(maxValue, event.eventValue, "Event value should be set from a valid numeric string.")
        XCTAssertTrue(event.isValid())

        // Above Max
        let aboveMax = maxValue.decimalValue.advanced(by: 0.000001)
        event = CustomEvent(name: "event name", stringValue: "\(aboveMax)")
        XCTAssertFalse(event.isValid())

        // Min value
        let minValue = NSNumber(value: Int32.min)
        event = CustomEvent(name: "event name", stringValue: minValue.stringValue)
        XCTAssertEqual(minValue, event.eventValue, "Event value should be set from a valid numeric string.")
        XCTAssertTrue(event.isValid())

        // Below min
        let belowMin = minValue.decimalValue.advanced(by: -0.000001)
        event = CustomEvent(name: "event name", stringValue: "\(belowMin)")
        XCTAssertFalse(event.isValid())

        // 0
        event = CustomEvent(name: "event name", stringValue: "0")
        XCTAssertEqual(0, event.eventValue, "Event value should be set from a valid numeric string.")
        XCTAssertTrue(event.isValid())

        // nil
        event = CustomEvent(name: "event name", stringValue: nil)
        XCTAssertNil(event.eventValue)
        XCTAssertTrue(event.isValid())

        // NaN
        event = CustomEvent(name: "event name", stringValue: "blah")
        XCTAssertEqual(NSDecimalNumber.notANumber, event.eventValue)
        XCTAssertFalse(event.isValid())
    }
    
    /**
     * Test event value from an NSNumber.
     */
    func testSetEventValueNSNumber() {
        var event = CustomEvent(name: "event name", value: 100)
        XCTAssertEqual(100, event.eventValue)
        XCTAssert(event.isValid())
        
        // Max value
        let maxValue = NSNumber(value: Int32.max)
        event = CustomEvent(name: "event name", value: maxValue)
        XCTAssertEqual(maxValue, event.eventValue)
        XCTAssertTrue(event.isValid())

        // Above Max
        let aboveMax = NSDecimalNumber(string:"\(maxValue.decimalValue.advanced(by: 0.000001))")
        event = CustomEvent(name: "event name", value: aboveMax)
        XCTAssertFalse(event.isValid())

        // Min value
        let minValue = NSNumber(value: Int32.min)
        event = CustomEvent(name: "event name", value: minValue)
        XCTAssertEqual(minValue, event.eventValue)
        XCTAssertTrue(event.isValid())

        // Below min
        let belowMin = NSDecimalNumber(string:"\(minValue.decimalValue.advanced(by: -0.000001))")
        event = CustomEvent(name: "event name", value: belowMin)
        XCTAssertFalse(event.isValid())

        // 0
        event = CustomEvent(name: "event name", value: 0)
        XCTAssertEqual(0, event.eventValue?.intValue)
        XCTAssertTrue(event.isValid())

        // nil
        event = CustomEvent(name: "event name", value: nil)
        XCTAssertNil(event.eventValue)
        XCTAssertTrue(event.isValid())

        // NaN
        event = CustomEvent(name: "event name", value: NSDecimalNumber.notANumber)
        XCTAssertEqual(NSDecimalNumber.notANumber, event.eventValue)
        XCTAssertFalse(event.isValid())
    }
    
    /**
     * Test event value to data conversion.  The value should be a decimal multiplied by
     * 10^6 and cast to a long.
     */
    func testEventValueToData() {
        let event = CustomEvent(name: "event name", value: 123.123456789)
        XCTAssertEqual(NSNumber(value: 123123456), event.data["event_value"] as? NSNumber)
    }
    
    /**
     * Test event includes conversion send ID if available.
     */
    func testConversionSendID() {
        analytics.conversionSendID = "send id"
        let event = CustomEvent(name: "event name")
        XCTAssertEqual("send id", event.data["conversion_send_id"] as? String)
    }
    
    /**
     * Test setting the event conversion send ID.
     */
    func testSettingConversionSendID() {
        analytics.conversionSendID = "send id"
        
        let event = CustomEvent(name: "event name")
        event.conversionSendID = "direct send id"
        
        XCTAssertEqual("direct send id", event.data["conversion_send_id"] as? String)
    }
    
    /**
     * Test event includes conversion push metadata if available.
     */
    func testConversionPushMetadata() {
        analytics.conversionPushMetadata = "metadata"
        let event = CustomEvent(name: "event name")
        
        XCTAssertEqual("metadata", event.data["conversion_metadata"] as? String)
    }
    
    /**
     * Test setting the event conversion push metadata.
     */
    func testSettingConversionPushMetadata() {
        analytics.conversionPushMetadata = "metadata"
        let event = CustomEvent(name: "event name")
        event.conversionPushMetadata = "base64metadataString"
        
        XCTAssertEqual("base64metadataString", event.data["conversion_metadata"] as? String)
    }
    
    /**
     * Test track adds an event to analytics.
     */
    func testTrack() {
        let event = CustomEvent(name: "event name")
        event.track()
        
        XCTAssertEqual(1, self.analytics.customEvents.count)
        XCTAssertEqual(event, self.analytics.customEvents.first)
    }
    
    /**
     * Test max total property size is 65536 bytes.
     */
    func testMaxTotalPropertySize() {
        let event = CustomEvent(name: "event name")
        
        var properties: [String: NSNumber] = [:]
        (0...5000).forEach({ properties["\($0)"] = 324 })
        event.properties = properties
        
        XCTAssertTrue(event.isValid())
        
        (0...2000).forEach({ properties["\(5000 + $0)"] = 324 })
        event.properties = properties
        
        XCTAssertFalse(event.isValid())
    }
}
