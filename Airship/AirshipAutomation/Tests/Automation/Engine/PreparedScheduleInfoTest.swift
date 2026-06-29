/* Copyright Airship and Contributors */

import XCTest

@testable @_spi(AirshipInternal)
import AirshipAutomation

final class PreparedScheduleInfoTest: XCTestCase {
    func testMissingTriggerSessionID() throws {
        let json = """
        {
            "scheduleID": "some schedule"
        }
        """

        let info = try JSONDecoder().decode(
            PreparedScheduleInfo.self,
            from: json.data(using: .utf8)!
        )

        XCTAssertEqual("some schedule", info.scheduleID)
        XCTAssertFalse(info.triggerSessionID.isEmpty)
    }

    func testSendMetadataRoundtrip() throws {
        let original = PreparedScheduleInfo(
            scheduleID: "some-schedule",
            triggerSessionID: "some-session",
            priority: 0,
            sendMetadata: "encoded-send-metadata"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PreparedScheduleInfo.self, from: data)

        XCTAssertEqual("encoded-send-metadata", decoded.sendMetadata)
    }

    func testSendMetadataAbsentWhenNil() throws {
        let original = PreparedScheduleInfo(
            scheduleID: "some-schedule",
            triggerSessionID: "some-session",
            priority: 0
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PreparedScheduleInfo.self, from: data)

        XCTAssertNil(decoded.sendMetadata)
    }
}


