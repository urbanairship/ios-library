/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipAutomation
@testable import AirshipCore

final class LegacyInAppMessageTest: XCTestCase {
    let date = UATestDate(offset: 0, dateOverride: Date())
    
    func testParseMinPayload() {
        let payload: [String: Any] = [
            "identifier": "test-id",
            "display": [
                "type": "banner",
                "alert": "test alert"
            ]
        ]
        
        let message = LegacyInAppMessage(payload: payload, date: date)!
        
        XCTAssertNil(message.campaigns)
        XCTAssertNil(message.messageType)
        XCTAssertEqual(60 * 60 * 24 * 30, message.expiry.timeIntervalSince(date.now))
        XCTAssertEqual(15, message.duration)
        XCTAssertNil(message.extra)
        XCTAssertEqual(LegacyInAppMessage.DisplayType.banner, message.displayType)
        XCTAssertEqual(LegacyInAppMessage.Position.bottom, message.position)
        XCTAssertNil(message.primaryColor)
        XCTAssertNil(message.secondaryColor)
        XCTAssertNil(message.buttonGroup)
        XCTAssertNil(message.buttonActions)
        XCTAssertNil(message.onClick)
    }
    
    func testParseMaxPayload() {
        date.offset = 1
        
        let payload: [String: Any] = [
            "identifier": "test-id",
            "display": [
                "type": "banner",
                "alert": "test alert",
                "position": "top",
                "primary_color": "#ABCDEF",
                "secondary_color": "#FEDCBA",
                "duration": 100.0,
            ],
            "extra": ["extra_value": "some text"],
            "expiry": AirshipDateFormatter.string(fromDate: date.now, format: .isoDelimitter),
            "actions": [
                "on_click": ["onclick": "action"],
                "button_group": "button group",
                "button_actions": ["name": ["test": "json"]],
            ],
            "campaigns": ["test-campaing": "json"],
            "message_type": "test-message"
        ]
        
        let message = LegacyInAppMessage(payload: payload, date: date)!
        
        XCTAssertEqual(try! AirshipJSON.wrap(["test-campaing": "json"]), message.campaigns)
        XCTAssertEqual("test-message", message.messageType)
        XCTAssertEqual(
            AirshipDateFormatter.string(fromDate: date.now, format: .isoDelimitter),
            AirshipDateFormatter.string(fromDate: message.expiry, format: .isoDelimitter)
        )
        XCTAssertEqual(100, message.duration)
        XCTAssertEqual(try! AirshipJSON.wrap(["extra_value": "some text"]), message.extra)
        XCTAssertEqual(LegacyInAppMessage.DisplayType.banner, message.displayType)
        XCTAssertEqual(LegacyInAppMessage.Position.top, message.position)
        XCTAssertEqual("#ABCDEF", message.primaryColor)
        XCTAssertEqual("#FEDCBA", message.secondaryColor)
        XCTAssertEqual("button group", message.buttonGroup)
        XCTAssertEqual(["name": try! AirshipJSON.wrap(["test": "json"])], message.buttonActions)
        XCTAssertEqual(try! AirshipJSON.wrap(["onclick": "action"]), message.onClick)
    }
    
    func testOverrideId() {
        let payload: [String : Any] = [
            "identifier": "test-id",
            "display": [
                "type": "banner",
                "alert": "test alert"
            ]
        ]
        
        let overridId = "override"
        
        let message = LegacyInAppMessage(payload: payload, overrideId: overridId)!
        XCTAssertEqual(overridId, message.identifier)
    }
    
    func testOverrideOnClick() {
        let payload: [String: Any] = [
            "identifier": "test-id",
            "display": [
                "type": "banner",
                "alert": "test alert"
            ]
        ]
        
        let overridJson = try! AirshipJSON.wrap(["test": "json"])
        
        let message = LegacyInAppMessage(payload: payload, overrideOnClick: overridJson)!
        XCTAssertEqual(overridJson, message.onClick)
    }
    
    func testMissingRequiredFields() {
        var payload: [String: Any] = [
            "display": [
                "type": "banner",
                "alert": "test alert"
            ]
        ]
        XCTAssertNil(LegacyInAppMessage(payload: payload))
        
        payload = [
            "identifier": "test-id",
            "display": [
                "alert": "test alert"
            ]
        ]
        XCTAssertNil(LegacyInAppMessage(payload: payload))
        
        payload = [
            "identifier": "test-id",
            "display": [
                "type": "banner",
            ]
        ]
        XCTAssertNil(LegacyInAppMessage(payload: payload))
        
        payload = [
            "identifier": "test-id",
            "display": [
                "type": "invalid",
                "alert": "test alert"
            ]
        ]
        XCTAssertNil(LegacyInAppMessage(payload: payload))
    }
}

extension Dictionary {
    func toNsDictionary() -> NSDictionary {
        return NSDictionary(dictionary: self)
    }
}
