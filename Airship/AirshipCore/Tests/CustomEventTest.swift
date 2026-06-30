/* Copyright Airship and Contributors */

import Testing
@testable import AirshipCore
import Foundation

@Suite struct CustomEventTest {

    /**
     * Test creating a custom event.
     */
    @Test
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
        
        #expect(eventName == event.data["event_name"] as? String, "Unexpected event name.")
        #expect(transactionId == event.data["transaction_id"] as? String, "Unexpected transaction ID.")
        #expect(interactionId == event.data["interaction_id"] as? String, "Unexpected interaction ID.")
        #expect(interactionType == event.data["interaction_type"] as? String, "Unexpected interaction type.")
        #expect(templateType == event.data["template_type"] as? String, "Unexpected template type.")
        #expect(NSNumber(value: -2147483648000000) == event.data["event_value"] as? NSNumber, "Unexpected event value.")
    }
    
    /**
     * Test setting an event name.
     */
    @Test
    func testSetCustomEventName() {
        var event = CustomEvent(name: "event name")
        #expect(event.isValid())
        
        let largeName = "".padding(toLength: 255, withPad: "event-name", startingAt: 0)
        event.eventName = largeName
        #expect(event.isValid())
    }
    
    /**
     * Test setting the interaction ID.
     */
    @Test
    func testSetInteractionID() {
        var event = CustomEvent(name: "event name")
        #expect(event.interactionID == nil, "Interaction ID should default to nil")
        
        let longInteractionId = "".padding(toLength: 255, withPad: "INTERACTION_ID", startingAt: 0)
        event.interactionID = longInteractionId
        #expect(event.isValid())
        
        event.interactionID = nil
        #expect(event.isValid())
    }
    
    /**
     * Test setting the interaction type.
     */
    @Test
    func testSetInteractionType() {
        var event = CustomEvent(name: "event name")
        #expect(event.interactionType == nil, "Interaction type should default to nil")
        
        let longInteractionType = "".padding(toLength: 255, withPad: "INTERACTION_TYPE", startingAt: 0)
        event.interactionType = longInteractionType
        #expect(event.isValid())
        
        event.interactionType = nil
        #expect(event.isValid())
    }
    
    /**
     * Test setting the transaction ID
     */
    @Test
    func testSetTransactionID() {
        var event = CustomEvent(name: "event name")
        #expect(event.transactionID == nil, "Transaction ID should default to nil")

        let longTransactionID = "".padding(toLength: 255, withPad: "TRANSACTION_ID", startingAt: 0)

        event.transactionID = longTransactionID
        #expect(event.isValid())

        event.transactionID = nil
        #expect(event.isValid())
    }
    
    /**
     * Test set template type
     */
    @Test
    func testSetTemplateType() {
        var event = CustomEvent(name: "event name")
        #expect(event.templateType == nil, "Template type should default to nil")

        let longTemplateType = "".padding(toLength: 255, withPad: "TEMPLATE_TYPE", startingAt: 0)

        event.templateType = longTemplateType
        #expect(event.isValid())

        event.templateType = nil
        #expect(event.isValid())
    }

    @Test
    func testEventValue() {
        var event = CustomEvent(name: "event name", value: 100)
        #expect(100 == event.eventValue)
        #expect(event.isValid())
        
        // Max value
        let maxValue = Double(Int32.max)
        event = CustomEvent(name: "event name", value: maxValue)
        #expect(NSNumber(value: 2147483647000000) == event.data["event_value"] as? NSNumber)
        #expect(event.isValid())

        // Above Max
        let aboveMax = Decimal(maxValue).advanced(by: 0.0001).doubleValue
        event = CustomEvent(name: "event name", value: aboveMax)
        #expect(!(event.isValid()))

        // Min value
        let minValue = Double(Int32.min)
        event = CustomEvent(name: "event name", value: minValue)
        #expect(NSNumber(value: -2147483648000000) == event.data["event_value"] as? NSNumber)
        #expect(event.isValid())

        // Below min
        let belowMin = Decimal(minValue).advanced(by: -0.000001).doubleValue
        event = CustomEvent(name: "event name", value: belowMin)
        #expect(!(event.isValid()))

        // 0
        event = CustomEvent(name: "event name", value: 0)
        #expect(NSNumber(value: 0) == event.data["event_value"] as? NSNumber)
        #expect(event.isValid())

        // NaN
        event = CustomEvent(name: "event name", value: Double.nan)
        #expect(event.eventValue == Decimal(1.0))
        #expect(event.isValid())

        // Infinity
        event = CustomEvent(name: "event name", value: Double.infinity)
        #expect(event.eventValue == Decimal(1.0))
        #expect(event.isValid())
    }
    
    /**
     * Test event value to data conversion.  The value should be a decimal multiplied by
     * 10^6 and cast to a long.
     */
    @Test
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
            #expect(event.isValid())
            #expect(NSNumber(value: expected) == event.data["event_value"] as? NSNumber)
        }
    }

    @Test
    func testConversionSendID() {
        let data = CustomEvent(name: "event name")
            .eventBody(sendID: "send id", metadata: "metadata", formatValue: false)
        #expect("send id" == data.object?["conversion_send_id"]?.string)
        #expect("metadata" == data.object?["conversion_metadata"]?.string)
    }

    @Test
    func testConversionSendIDSet() {
        var event = CustomEvent(name: "event name")
        event.conversionSendID = "some other send id"
        event.conversionPushMetadata = "some other metadata"

        let data = event.eventBody(sendID: "send id", metadata: "metadata", formatValue: false)
        #expect("some other send id" == data.object?["conversion_send_id"]?.string)
        #expect("some other metadata" == data.object?["conversion_metadata"]?.string)
    }

    @Test
    func testMaxTotalPropertySize() throws {
        var event = CustomEvent(name: "event name")

        var properties: [String: NSNumber] = [:]
        (0...5000).forEach({ properties["\($0)"] = 324 })
        try event.setProperties(properties)

        #expect(event.isValid())
        
        (0...2000).forEach({ properties["\(5000 + $0)"] = 324 })
        try event.setProperties(properties)

        #expect(!(event.isValid()))
    }

    @Test
    func testInApp() {
        var event = CustomEvent(name: "event name")

        // Defined in automation, just make sure it passes it through
        event.inApp = AirshipJSON.makeObject { builder in
            builder.set(string: "foo", key: "bar")
        }

        let result = try! AirshipJSON.wrap(event.data["in_app"])

        #expect(event.inApp == result)
    }

    @Test
    func testCodableProperties() throws {
        var event = CustomEvent(name: "event name")

        try event.setProperties([
            "some-codable": TestCodable(string: "foo", bool: false)
        ])
        let properties = event.data["properties"] as! [String: Any]
        let someCodable = properties["some-codable"] as! [String: Any]

        #expect("foo" == someCodable["string"] as! String)
        #expect(false == someCodable["bool"] as! Bool)
    }

    @Test
    func testDateProperties() throws {
        var event = CustomEvent(name: "event name")
        try event.setProperties([
            "some-date": Date(timeIntervalSince1970: 10000.0)
        ])

        let properties = event.data["properties"] as! [String: Any]
        #expect("1970-01-01T02:46:40Z" == properties["some-date"] as! String)
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
