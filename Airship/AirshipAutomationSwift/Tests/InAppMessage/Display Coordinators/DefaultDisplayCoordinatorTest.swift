/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipAutomationSwift
import AirshipCore

final class DefaultDisplayCoordinatorTest: XCTestCase {

    private let stateTracker: TestAppStateTracker = TestAppStateTracker()
    private var displayCoordinator: DefaultDisplayCoordinator!
    private let taskSleeper: TestTaskSleeper = TestTaskSleeper()

    let fooSchedule = InAppMessage(name: "foo", displayContent: .custom(.string("foo")))

    @MainActor
    override func setUp() async throws {
        displayCoordinator = DefaultDisplayCoordinator(
            displayInterval: 10.0,
            appStateTracker: self.stateTracker,
            taskSleeper: self.taskSleeper
        )
    }

    @MainActor
    func testIsReady() throws {
        self.stateTracker.currentState = .active
        XCTAssertTrue(self.displayCoordinator.isReady)

        self.stateTracker.currentState = .background
        XCTAssertFalse(self.displayCoordinator.isReady)

        self.stateTracker.currentState = .inactive
        XCTAssertFalse(self.displayCoordinator.isReady)
    }

    @MainActor
    func testIsReadyLocking() async throws {
        self.stateTracker.currentState = .active
        XCTAssertTrue(self.displayCoordinator.isReady)

        self.displayCoordinator.didBeginDisplayingMessage(fooSchedule)
        XCTAssertFalse(self.displayCoordinator.isReady)

        self.displayCoordinator.didFinishDisplayingMessage(fooSchedule)
        await self.displayCoordinator.waitForReady()
        XCTAssertTrue(self.displayCoordinator.isReady)

        XCTAssertEqual([10], self.taskSleeper.sleeps)
    }

    @MainActor
    func testWaitForReady() async throws {
        self.stateTracker.currentState = .background

        let ready = Task { [displayCoordinator] in
            await displayCoordinator!.waitForReady()
        }

        self.stateTracker.currentState = .active
        await ready.value
    }
}
