/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Action automation protocol
protocol ActionAutomationProtocol: Sendable {
    func runActions(_ actions: AirshipJSON) async
}

/// Action runner
protocol AutomationActionRunner: Sendable {
    func runActions(_ actions: AirshipJSON, situation: ActionSituation, metadata: [String: Sendable]) async
}

final class ActionAutomation: AutomationExecutorDelegate, AutomationPreparerDelegate {
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

    func cancelled(scheduleID: String) async {
        // no-op
    }

    func prepare(data: AirshipJSON, preparedScheduleInfo: PreparedScheduleInfo) async throws -> AirshipJSON {
        return data
    }
}

/// Default action runner
fileprivate struct DefaultRunner: AutomationActionRunner {
    func runActions(_ actions: AirshipJSON, situation: ActionSituation, metadata: [String: Sendable]) async {
        await ActionRunner.run(actionsPayload: actions, situation: .automation, metadata: metadata)
    }
}


