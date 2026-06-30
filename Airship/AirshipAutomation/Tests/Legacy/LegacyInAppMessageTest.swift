/* Copyright Airship and Contributors */

import Testing
import Foundation
@testable @_spi(AirshipInternal) import AirshipAutomation
@testable import AirshipCore
@_spi(AirshipInternal) import AirshipBasement

struct LegacyInAppMessageTest {
    let date = UATestDate(offset: 0, dateOverride: Date())
    
    @Test
    func testParseMinPayload() {
        let payload: [String: Any] = [
            "identifier": "test-id",
            "display": [
                "type": "banner",
                "alert": "test alert"
            ]
        ]
        
        let message = LegacyInAppMessage(payload: payload, date: date)!
        
        #expect(message.campaigns == nil)
        #expect(message.messageType == nil)
        #expect(60 * 60 * 24 * 30 == message.expiry.timeIntervalSince(date.now))
        #expect(15 == message.duration)
        #expect(message.extra == nil)
        #expect(LegacyInAppMessage.DisplayType.banner == message.displayType)
        #expect(LegacyInAppMessage.Position.bottom == message.position)
        #expect(message.primaryColor == nil)
        #expect(message.secondaryColor == nil)
        #expect(message.buttonGroup == nil)
        #expect(message.buttonActions == nil)
        #expect(message.onClick == nil)
    }
    
    @Test
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
            "expiry": AirshipDateFormatter.string(fromDate: date.now, format: .iso8601),
            "actions": [
                "on_click": ["onclick": "action"],
                "button_group": "button group",
                "button_actions": ["name": ["test": "json"]],
            ],
            "campaigns": ["test-campaing": "json"],
            "message_type": "test-message"
        ]
        
        let message = LegacyInAppMessage(payload: payload, date: date)!
        
        #expect(try! AirshipJSON.wrap(["test-campaing": "json"]) == message.campaigns)
        #expect("test-message" == message.messageType)
        #expect(
            AirshipDateFormatter.string(fromDate: date.now, format: .iso8601) ==
            AirshipDateFormatter.string(fromDate: message.expiry, format: .iso8601)
        )
        #expect(100 == message.duration)
        #expect(try! AirshipJSON.wrap(["extra_value": "some text"]) == message.extra)
        #expect(LegacyInAppMessage.DisplayType.banner == message.displayType)
        #expect(LegacyInAppMessage.Position.top == message.position)
        #expect("#ABCDEF" == message.primaryColor)
        #expect("#FEDCBA" == message.secondaryColor)
        #expect("button group" == message.buttonGroup)
        #expect(["name": try! AirshipJSON.wrap(["test": "json"])] == message.buttonActions)
        #expect(try! AirshipJSON.wrap(["onclick": "action"]) == message.onClick)
    }
    
    @Test
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
        #expect(overridId == message.identifier)
    }
    
    @Test
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
        #expect(overridJson == message.onClick)
    }
    
    @Test
    func testMissingRequiredFields() {
        var payload: [String: Any] = [
            "display": [
                "type": "banner",
                "alert": "test alert"
            ]
        ]
        #expect(LegacyInAppMessage(payload: payload) == nil)
        
        payload = [
            "identifier": "test-id",
            "display": [
                "alert": "test alert"
            ]
        ]
        #expect(LegacyInAppMessage(payload: payload) == nil)
        
        payload = [
            "identifier": "test-id",
            "display": [
                "type": "banner",
            ]
        ]
        #expect(LegacyInAppMessage(payload: payload) == nil)
        
        payload = [
            "identifier": "test-id",
            "display": [
                "type": "invalid",
                "alert": "test alert"
            ]
        ]
        #expect(LegacyInAppMessage(payload: payload) == nil)
    }
}

extension Dictionary {
    func toNsDictionary() -> NSDictionary {
        return NSDictionary(dictionary: self)
    }
}
