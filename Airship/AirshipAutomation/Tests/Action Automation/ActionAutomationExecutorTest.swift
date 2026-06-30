/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable @_spi(AirshipInternal)
import AirshipAutomation
import AirshipCore

struct ActionAutomationExecutorTest {

    private let actionRunner: TestActionRunner = TestActionRunner()
    private let executor: ActionAutomationExecutor

    private let preparedScheduleInfo = PreparedScheduleInfo(scheduleID: "some id", triggerSessionID: UUID().uuidString, priority: 0)
    private let actions = try! AirshipJSON.wrap(["some-action": "some-value"])

    init() {
        self.executor = ActionAutomationExecutor(actionRunner: actionRunner)
    }

    @Test
    func testExecute() async throws {
        let result = await self.executor.execute(data: actions, preparedScheduleInfo: preparedScheduleInfo)

        #expect(self.actionRunner.actions == actions)
        #expect(self.actionRunner.situation == .automation)
        #expect(self.actionRunner.metadata!.isEmpty)
        #expect(result == .finished)
    }

    @Test
    func testIsReady() async throws {
        let result = await self.executor.isReady(data: actions, preparedScheduleInfo: preparedScheduleInfo)
        #expect(result == .ready)
    }
}


