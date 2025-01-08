/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipCore

final class CustomEventTest: XCTestCase {

    /**
     * Test creating a custom event.
     */
    func testCustomEvent() {
        let eventName = "".padding(toLength: 255, withPad: "EVENT_NAME", startingAt: 0)
        let transactionId = "".padding(toLength: 255, withPad: "TRANSACTION_ID", startingAt: 0)
        let interactionId = "".padding(toLength: 255, withPad: "INTERACTION_ID", startingAt: 0)
        let interactionType = "".padding(toLength: 255, withPad: "INTERACTION_TYPE", startingAt: 0)
        let templateType = "".padding(toLength: 255, withPad: "TEMPLATE_TYPE", startingAt: 0)
        
        var event = CustomEvent(name: eventName, value: Double(Int32.min))
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
        var event = CustomEvent(name: "event name")
        XCTAssert(event.isValid())
        
        let largeName = "".padding(toLength: 255, withPad: "event-name", startingAt: 0)
        event.eventName = largeName
        XCTAssert(event.isValid())
    }
    
    /**
     * Test setting the interaction ID.
     */
    func testSetInteractionID() {
        var event = CustomEvent(name: "event name")
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
        var event = CustomEvent(name: "event name")
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
        var event = CustomEvent(name: "event name")
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
        var event = CustomEvent(name: "event name")
        XCTAssertNil(event.templateType, "Template type should default to nil")

        let longTemplateType = "".padding(toLength: 255, withPad: "TEMPLATE_TYPE", startingAt: 0)

        event.templateType = longTemplateType
        XCTAssertTrue(event.isValid())

        event.templateType = nil
        XCTAssertTrue(event.isValid())
    }

    func testEventValue() {
        var event = CustomEvent(name: "event name", value: 100)
        XCTAssertEqual(100, event.eventValue)
        XCTAssert(event.isValid())
        
        // Max value
        let maxValue = Double(Int32.max)
        event = CustomEvent(name: "event name", value: maxValue)
        XCTAssertEqual(NSNumber(value: 2147483647000000), event.data["event_value"] as? NSNumber)
        XCTAssertTrue(event.isValid())

        // Above Max
        let aboveMax = Decimal(maxValue).advanced(by: 0.0001).doubleValue
        event = CustomEvent(name: "event name", value: aboveMax)
        XCTAssertFalse(event.isValid())

        // Min value
        let minValue = Double(Int32.min)
        event = CustomEvent(name: "event name", value: minValue)
        XCTAssertEqual(NSNumber(value: -2147483648000000), event.data["event_value"] as? NSNumber)
        XCTAssertTrue(event.isValid())

        // Below min
        let belowMin = Decimal(minValue).advanced(by: -0.000001).doubleValue
        event = CustomEvent(name: "event name", value: belowMin)
        XCTAssertFalse(event.isValid())

        // 0
        event = CustomEvent(name: "event name", value: 0)
        XCTAssertEqual(NSNumber(value: 0), event.data["event_value"] as? NSNumber)
        XCTAssertTrue(event.isValid())

        // NaN
        event = CustomEvent(name: "event name", value: Double.nan)
        XCTAssertEqual(event.eventValue, Decimal(1.0))
        XCTAssertTrue(event.isValid())

        // Infinity
        event = CustomEvent(name: "event name", value: Double.infinity)
        XCTAssertEqual(event.eventValue, Decimal(1.0))
        XCTAssertTrue(event.isValid())
    }
    
    /**
     * Test event value to data conversion.  The value should be a decimal multiplied by
     * 10^6 and cast to a long.
     */
    func testEventValueToData() {
        let eventValues: [Decimal: Int64] = [
            123.123456789: 123123456,
            9.999999999: 9999999,
            99.999999999: 99999999,
            999.999999999: 999999999,
            9999.999999999: 9999999999,
            99999.999999999: 99999999999,
            999999.999999999: 999999999999,
            9999999.999999999: 9999999999999
        ]

        eventValues.forEach { value, expected in
            let event = CustomEvent(name: "event name", decimalValue: value)
            XCTAssertTrue(event.isValid())
            XCTAssertEqual(NSNumber(value: expected), event.data["event_value"] as? NSNumber)
        }
    }

    func testConversionSendID() {
        let data = CustomEvent(name: "event name")
            .eventBody(sendID: "send id", metadata: "metadata", formatValue: false)
        XCTAssertEqual("send id", data.object?["conversion_send_id"]?.string)
        XCTAssertEqual("metadata", data.object?["conversion_metadata"]?.string)
    }

    func testConversionSendIDSet() {
        var event = CustomEvent(name: "event name")
        event.conversionSendID = "some other send id"
        event.conversionPushMetadata = "some other metadata"

        let data = event.eventBody(sendID: "send id", metadata: "metadata", formatValue: false)
        XCTAssertEqual("some other send id", data.object?["conversion_send_id"]?.string)
        XCTAssertEqual("some other metadata", data.object?["conversion_metadata"]?.string)
    }

    func testMaxTotalPropertySize() throws {
        var event = CustomEvent(name: "event name")

        var properties: [String: NSNumber] = [:]
        (0...5000).forEach({ properties["\($0)"] = 324 })
        try event.setProperties(properties)

        XCTAssertTrue(event.isValid())
        
        (0...2000).forEach({ properties["\(5000 + $0)"] = 324 })
        try event.setProperties(properties)

        XCTAssertFalse(event.isValid())
    }

    func testInApp() {
        var event = CustomEvent(name: "event name")

        // Defined in automation, just make sure it passes it through
        event.inApp = AirshipJSON.makeObject { builder in
            builder.set(string: "foo", key: "bar")
        }

        let result = try! AirshipJSON.wrap(event.data["in_app"])

        XCTAssertEqual(event.inApp, result)
    }

    func testCodableProperties() throws {
        var event = CustomEvent(name: "event name")

        try event.setProperties([
            "some-codable": TestCodable(string: "foo", bool: false)
        ])
        let properties = event.data["properties"] as! [String: Any]
        let someCodable = properties["some-codable"] as! [String: Any]

        XCTAssertEqual("foo", someCodable["string"] as! String)
        XCTAssertEqual(false, someCodable["bool"] as! Bool)
    }

    func testDateProperties() throws {
        var event = CustomEvent(name: "event name")
        try event.setProperties([
            "some-date": Date(timeIntervalSince1970: 10000.0)
        ])

        let properties = event.data["properties"] as! [String: Any]
        XCTAssertEqual("1970-01-01T02:46:40Z", properties["some-date"] as! String)
    }
}

fileprivate struct TestCodable: Encodable {
    let string: String
    let bool: Bool
}

extension CustomEvent {
    var data: [AnyHashable: Any] {
        return self.eventBody(
            sendID: nil,
            metadata: nil,
            formatValue: true
        ).unWrap() as? [AnyHashable : Any] ?? [:]
    }
}

extension Decimal {
    var doubleValue: Double {
        return NSDecimalNumber(decimal:self).doubleValue
    }
}
