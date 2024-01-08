/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipAutomationSwift
import AirshipCore

class ActionAutomationTest: XCTestCase {

    private let actionRunner: TestActionRunner = TestActionRunner()
    private var actionAutomation: ActionAutomation!

    private let preparedScheduleInfo = PreparedScheduleInfo(scheduleID: "some id")
    private let actions = try! AirshipJSON.wrap(["some-action": "some-value"])

    override func setUp() {
        self.actionAutomation = ActionAutomation(actionRunner: actionRunner)
    }

    func testExecute() async throws {
        await self.actionAutomation.execute(data: actions, preparedScheduleInfo: preparedScheduleInfo)

        XCTAssertEqual(self.actionRunner.actions, actions)
        XCTAssertEqual(self.actionRunner.situation, .automation)
        XCTAssertTrue(self.actionRunner.metadata!.isEmpty)
    }

    func testIsReady() async throws {
        let result = await self.actionAutomation.isReady(data: actions, preparedScheduleInfo: preparedScheduleInfo)
        XCTAssertEqual(result, .ready)
    }

    func testPrepare() async throws {
        let result = try await self.actionAutomation.prepare(data: actions, preparedScheduleInfo: preparedScheduleInfo)
        XCTAssertEqual(actions, result)
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

