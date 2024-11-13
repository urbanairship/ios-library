/* Copyright Airship and Contributors */

import Foundation
#if canImport(AirshipCore)
import AirshipCore
#endif


/// Action runner
protocol AutomationActionRunnerProtocol: Sendable {
    func runActions(_ actions: AirshipJSON, situation: ActionSituation, metadata: [String: any Sendable]) async
}

/// Default action runner
struct AutomationActionRunner: AutomationActionRunnerProtocol {
    func runActions(_ actions: AirshipJSON, situation: ActionSituation, metadata: [String: any Sendable]) async {
        await ActionRunner.run(actionsPayload: actions, situation: situation, metadata: metadata)
    }
}
