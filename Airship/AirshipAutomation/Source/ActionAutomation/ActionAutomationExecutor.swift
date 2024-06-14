/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

struct ActionAutomationExecutor: AutomationExecutorDelegate {
    typealias PrepareDataIn = AirshipJSON
    typealias PrepareDataOut = AirshipJSON
    typealias ExecutionData = AirshipJSON

    private let actionRunner: AutomationActionRunnerProtocol

    init(actionRunner: AutomationActionRunnerProtocol = AutomationActionRunner()) {
        self.actionRunner = actionRunner
    }

    func isReady(data: AirshipJSON, preparedScheduleInfo: PreparedScheduleInfo) -> ScheduleReadyResult {
        return .ready
    }

    func execute(data: AirshipJSON, preparedScheduleInfo: PreparedScheduleInfo) async -> ScheduleExecuteResult {
        guard preparedScheduleInfo.additionalAudienceCheckResult else {
            return .finished
        }

        await actionRunner.runActions(data, situation: .automation, metadata: [:])
        return .finished
    }

    func interrupted(schedule: AutomationSchedule, preparedScheduleInfo: PreparedScheduleInfo) async -> InterruptedBehavior {
        return .retry
    }
}
