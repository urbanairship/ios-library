/* Copyright Airship and Contributors */

import Foundation
#if canImport(AirshipCore)
import AirshipCore
#endif


/// Action runner
protocol AutomationActionRunnerProtocol: Sendable {
    func runActions(_ actions: AirshipJSON, situation: ActionSituation, metadata: [String: Sendable]) async
    func runActionsAsync(_ actions: AirshipJSON, situation: ActionSituation, metadata: [String: Sendable])
}

/// Default action runner
struct AutomationActionRunner: AutomationActionRunnerProtocol {
    func runActionsAsync(_ actions: AirshipJSON, situation: ActionSituation, metadata: [String : Sendable]) {
        Task {
            await ActionRunner.run(actionsPayload: actions, situation: situation, metadata: metadata)
        }
    }
    
    func runActions(_ actions: AirshipJSON, situation: ActionSituation, metadata: [String: Sendable]) async {
        await ActionRunner.run(actionsPayload: actions, situation: situation, metadata: metadata)
    }
}
