/* Copyright Airship and Contributors */

import Foundation

import AirshipCore

struct ActionAutomationExecutor: AutomationExecutorDelegate {
    typealias PrepareDataIn = AirshipJSON
    typealias PrepareDataOut = AirshipJSON
    typealias ExecutionData = AirshipJSON

    private let actionRunner: any AutomationActionRunnerProtocol
    private let ledger: any AutomationLedgerProtocol

    init(
        actionRunner: any AutomationActionRunnerProtocol = AutomationActionRunner(),
        ledger: any AutomationLedgerProtocol
    ) {
        self.actionRunner = actionRunner
        self.ledger = ledger
    }

    func isReady(data: AirshipJSON, preparedScheduleInfo: PreparedScheduleInfo) -> ScheduleReadyResult {
        return .ready
    }

    func execute(data: AirshipJSON, preparedScheduleInfo: PreparedScheduleInfo) async -> ScheduleExecuteResult {
        guard preparedScheduleInfo.additionalAudienceCheckResult else {
            return .finished
        }

        await actionRunner.runActions(data, situation: .automation, metadata: [:])

        await self.ledger.recordExecution(
            scheduleID: preparedScheduleInfo.scheduleID,
            sharedID: preparedScheduleInfo.ledgerSharedID,
            triggerID: preparedScheduleInfo.triggerID,
            result: .succeeded,
            cancel: false
        )

        return .finished
    }

    func interrupted(schedule: AutomationSchedule, preparedScheduleInfo: PreparedScheduleInfo) async -> InterruptedBehavior {
        return .retry
    }
}
