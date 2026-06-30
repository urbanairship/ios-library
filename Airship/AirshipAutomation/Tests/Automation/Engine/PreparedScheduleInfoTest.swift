/* Copyright Airship and Contributors */

import Foundation
import Testing

@testable @_spi(AirshipInternal)
import AirshipAutomation

struct PreparedScheduleInfoTest {
    @Test
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

        #expect("some schedule" == info.scheduleID)
        #expect(!(info.triggerSessionID.isEmpty))
    }

    @Test
    func testSendMetadataRoundtrip() throws {
        let original = PreparedScheduleInfo(
            scheduleID: "some-schedule",
            triggerSessionID: "some-session",
            priority: 0,
            sendMetadata: "encoded-send-metadata"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PreparedScheduleInfo.self, from: data)

        #expect("encoded-send-metadata" == decoded.sendMetadata)
    }

    @Test
    func testSendMetadataAbsentWhenNil() throws {
        let original = PreparedScheduleInfo(
            scheduleID: "some-schedule",
            triggerSessionID: "some-session",
            priority: 0
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PreparedScheduleInfo.self, from: data)

        #expect(decoded.sendMetadata == nil)
    }
}


