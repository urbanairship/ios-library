/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipAutomation
import AirshipCore

final class ActionPreparerTest: XCTestCase {

    private let preparer: ActionAutomationPreparer = ActionAutomationPreparer()
    private let actions = try! AirshipJSON.wrap(["some-action": "some-value"])
    private let preparedScheduleInfo = PreparedScheduleInfo(scheduleID: "some id")

    func testPrepare() async throws {
        let result = try await self.preparer.prepare(data: actions, preparedScheduleInfo: preparedScheduleInfo)
        XCTAssertEqual(actions, result)
    }
}
