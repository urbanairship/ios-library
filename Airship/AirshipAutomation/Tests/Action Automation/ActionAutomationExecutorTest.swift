/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable @_spi(AirshipInternal)
import AirshipAutomation
import AirshipCore

struct ActionAutomationExecutorTest {

    private let actionRunner: TestActionRunner = TestActionRunner()
    private let ledger: TestAutomationLedger = TestAutomationLedger()
    private let executor: ActionAutomationExecutor

    private let preparedScheduleInfo = PreparedScheduleInfo(
        scheduleID: "some id",
        triggerSessionID: UUID().uuidString,
        priority: 0,
        ledgerSharedID: "group-1",
        triggerID: "trigger-1"
    )
    private let actions = try! AirshipJSON.wrap(["some-action": "some-value"])

    init() {
        self.executor = ActionAutomationExecutor(actionRunner: actionRunner, ledger: ledger)
    }

    @Test
    func testExecute() async throws {
        let result = await self.executor.execute(data: actions, preparedScheduleInfo: preparedScheduleInfo)

        #expect(self.actionRunner.actions == actions)
        #expect(self.actionRunner.situation == .automation)
        #expect(self.actionRunner.metadata!.isEmpty)
        #expect(result == .finished)

        #expect(await self.ledger.recorded == [
            .execution(
                scheduleID: "some id",
                sharedID: "group-1",
                triggerID: "trigger-1",
                result: .succeeded,
                cancel: false
            )
        ])
    }

    @Test
    func testAdditionalAudienceMissRecordsNothing() async throws {
        var info = preparedScheduleInfo
        info.additionalAudienceCheckResult = false

        let result = await self.executor.execute(data: actions, preparedScheduleInfo: info)

        #expect(result == .finished)
        #expect(self.actionRunner.actions == nil)
        #expect(await self.ledger.recorded.isEmpty)
    }

    @Test
    func testIsReady() async throws {
        let result = await self.executor.isReady(data: actions, preparedScheduleInfo: preparedScheduleInfo)
        #expect(result == .ready)
    }
}


