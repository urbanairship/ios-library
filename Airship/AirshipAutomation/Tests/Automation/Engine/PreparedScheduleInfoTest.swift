/* Copyright Airship and Contributors */

import XCTest

@testable
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
}


