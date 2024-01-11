/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Action runner
protocol AutomationActionRunner: Sendable {
    func runActions(_ actions: AirshipJSON, situation: ActionSituation, metadata: [String: Sendable]) async
}

struct ActionAutomationExecutor: AutomationExecutorDelegate {
    typealias PrepareDataIn = AirshipJSON
    typealias PrepareDataOut = AirshipJSON
    typealias ExecutionData = AirshipJSON

    private let actionRunner: AutomationActionRunner

    init(actionRunner: AutomationActionRunner = DefaultRunner()) {
        self.actionRunner = actionRunner
    }

    func isReady(data: AirshipJSON, preparedScheduleInfo: PreparedScheduleInfo) -> ScheduleReadyResult {
        return .ready
    }

    func execute(data: AirshipJSON, preparedScheduleInfo: PreparedScheduleInfo) async {
        await actionRunner.runActions(data, situation: .automation, metadata: [:])
    }

    func interrupted(preparedScheduleInfo: PreparedScheduleInfo) async {
        // no-op
    }
}

/// Default action runner
fileprivate struct DefaultRunner: AutomationActionRunner {
    func runActions(_ actions: AirshipJSON, situation: ActionSituation, metadata: [String: Sendable]) async {
        await ActionRunner.run(actionsPayload: actions, situation: .automation, metadata: metadata)
    }
}


