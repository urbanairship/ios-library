/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable @_spi(AirshipInternal)
import AirshipAutomation
import AirshipCore

struct ActionPreparerTest {

    private let preparer: ActionAutomationPreparer = ActionAutomationPreparer()
    private let actions = try! AirshipJSON.wrap(["some-action": "some-value"])
    private let preparedScheduleInfo = PreparedScheduleInfo(scheduleID: "some id", triggerSessionID: UUID().uuidString, priority: 0)

    @Test
    func testPrepare() async throws {
        guard case .prepared(let result) = try await self.preparer.prepare(data: actions, preparedScheduleInfo: preparedScheduleInfo) else {
            Issue.record("Expected .prepared result")
            return
        }
        #expect(actions == result)
    }
}
