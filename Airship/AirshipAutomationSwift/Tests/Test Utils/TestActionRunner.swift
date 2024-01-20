/* Copyright Airship and Contributors */

import Foundation

@testable import AirshipAutomationSwift
@testable import AirshipCore

final class TestActionRunner: AutomationActionRunnerProtocol, @unchecked Sendable {

    var actions: AirshipJSON?
    var situation: ActionSituation?
    var metadata: [String: Sendable]?

    func runActions(_ actions: AirshipCore.AirshipJSON, situation: ActionSituation, metadata: [String : Sendable]) async {
        self.actions = actions
        self.situation = situation
        self.metadata = metadata
    }

    func runActionsAsync(_ actions: AirshipCore.AirshipJSON, situation: ActionSituation, metadata: [String : Sendable]) {
        self.actions = actions
        self.situation = situation
        self.metadata = metadata
    }
}
