/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipAutomationSwift
import AirshipCore

class ActionAutomationExecutorTest: XCTestCase {

    private let actionRunner: TestActionRunner = TestActionRunner()
    private var executor: ActionAutomationExecutor!

    private let preparedScheduleInfo = PreparedScheduleInfo(scheduleID: "some id")
    private let actions = try! AirshipJSON.wrap(["some-action": "some-value"])

    override func setUp() {
        self.executor = ActionAutomationExecutor(actionRunner: actionRunner)
    }

    func testExecute() async throws {
        await self.executor.execute(data: actions, preparedScheduleInfo: preparedScheduleInfo)

        XCTAssertEqual(self.actionRunner.actions, actions)
        XCTAssertEqual(self.actionRunner.situation, .automation)
        XCTAssertTrue(self.actionRunner.metadata!.isEmpty)
    }

    func testIsReady() async throws {
        let result = await self.executor.isReady(data: actions, preparedScheduleInfo: preparedScheduleInfo)
        XCTAssertEqual(result, .ready)
    }
}

fileprivate final class TestActionRunner: AutomationActionRunner, @unchecked Sendable {

    var actions: AirshipJSON?
    var situation: ActionSituation?
    var metadata: [String: Sendable]?

    func runActions(_ actions: AirshipCore.AirshipJSON, situation: ActionSituation, metadata: [String : Sendable]) async {
        self.actions = actions
        self.situation = situation
        self.metadata = metadata
    }
}

