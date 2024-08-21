/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipAutomation
import AirshipCore

class ActionAutomationExecutorTest: XCTestCase {

    private let actionRunner: TestActionRunner = TestActionRunner()
    private var executor: ActionAutomationExecutor!

    private let preparedScheduleInfo = PreparedScheduleInfo(scheduleID: "some id", triggerSessionID: UUID().uuidString, priority: 0)
    private let actions = try! AirshipJSON.wrap(["some-action": "some-value"])

    override func setUp() {
        self.executor = ActionAutomationExecutor(actionRunner: actionRunner)
    }

    func testExecute() async throws {
        let result = await self.executor.execute(data: actions, preparedScheduleInfo: preparedScheduleInfo)

        XCTAssertEqual(self.actionRunner.actions, actions)
        XCTAssertEqual(self.actionRunner.situation, .automation)
        XCTAssertTrue(self.actionRunner.metadata!.isEmpty)
        XCTAssertEqual(result, .finished)
    }

    func testIsReady() async throws {
        let result = await self.executor.isReady(data: actions, preparedScheduleInfo: preparedScheduleInfo)
        XCTAssertEqual(result, .ready)
    }
}


