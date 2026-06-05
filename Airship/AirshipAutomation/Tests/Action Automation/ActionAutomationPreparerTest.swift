/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipAutomation
import AirshipCore

final class ActionPreparerTest: XCTestCase {

    private let preparer: ActionAutomationPreparer = ActionAutomationPreparer()
    private let actions = try! AirshipJSON.wrap(["some-action": "some-value"])
    private let preparedScheduleInfo = PreparedScheduleInfo(scheduleID: "some id", triggerSessionID: UUID().uuidString, priority: 0)

    func testPrepare() async throws {
        guard case .prepared(let result) = try await self.preparer.prepare(data: actions, preparedScheduleInfo: preparedScheduleInfo) else {
            return XCTFail("Expected .prepared result")
        }
        XCTAssertEqual(actions, result)
    }
}
