/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipCore

final class CompoundDeviceAudienceSelectorTest: XCTestCase, @unchecked Sendable {

    func testParsing() throws {
        [
            (
                CompoundDeviceAudienceSelector.atomic(DeviceAudienceSelector(newUser: true)),
                "{\"type\":\"atomic\", \"audience\":{\"new_user\":true}}"
            ),
            (
                CompoundDeviceAudienceSelector.not(.atomic(DeviceAudienceSelector(newUser: true))),
                "{\"type\":\"not\", \"selector\": {\"type\":\"atomic\", \"audience\":{\"new_user\":true}}}"
            ),
            (
                CompoundDeviceAudienceSelector.and([
                    .atomic(DeviceAudienceSelector(newUser: true)),
                    .atomic(DeviceAudienceSelector(newUser: false))]
                ),
                "{\"type\":\"and\", \"selectors\": [{\"type\":\"atomic\", \"audience\":{\"new_user\":true}},{\"type\":\"atomic\", \"audience\":{\"new_user\":false}}]}"
            ),
            (
                CompoundDeviceAudienceSelector.and([]),
                "{\"type\":\"and\", \"selectors\": []}"
            ),
            (
                CompoundDeviceAudienceSelector.or([
                    .atomic(DeviceAudienceSelector(newUser: true)),
                    .atomic(DeviceAudienceSelector(newUser: false))]
                ),
                "{\"type\":\"or\", \"selectors\": [{\"type\":\"atomic\", \"audience\":{\"new_user\":true}},{\"type\":\"atomic\", \"audience\":{\"new_user\":false}}]}"
            ),
            (
                CompoundDeviceAudienceSelector.or([]),
                "{\"type\":\"or\", \"selectors\": []}"
            ),
            
        ].forEach { (key, value) in
            checkEqualRoundTrip(original: key, json: value)
        }
    }

    private func checkEqualRoundTrip(original: CompoundDeviceAudienceSelector, json: String) {
        let decoder = JSONDecoder()
        let fromSource = try! decoder.decode(CompoundDeviceAudienceSelector.self, from: json.data(using: .utf8)!)

        XCTAssertEqual(original, fromSource)
        
        let roundTrip = try! decoder.decode(CompoundDeviceAudienceSelector.self, from: try JSONEncoder().encode(fromSource))
        XCTAssertEqual(original, roundTrip)
    }
}
