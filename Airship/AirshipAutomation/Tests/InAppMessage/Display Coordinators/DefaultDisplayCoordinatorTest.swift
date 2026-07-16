/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable @_spi(AirshipInternal)
import AirshipAutomation
import AirshipCore
@_spi(AirshipInternal) import AirshipBasement

@MainActor
struct DefaultDisplayCoordinatorTest {

    private let stateTracker: TestAppStateTracker = TestAppStateTracker()
    private let displayCoordinator: DefaultDisplayCoordinator
    private let activityTracker: DisplayActivityTracker
    private let taskSleeper: TestTaskSleeper = TestTaskSleeper()

    let fooSchedule = InAppMessage(name: "foo", displayContent: .custom(.string("foo")))

    init() {
        self.activityTracker = DisplayActivityTracker()
        displayCoordinator = DefaultDisplayCoordinator(
            displayInterval: 10.0,
            activityTracker: self.activityTracker,
            appStateTracker: self.stateTracker,
            taskSleeper: self.taskSleeper
        )
    }

    @Test
    func testIsReady() throws {
        self.stateTracker.currentState = .active
        #expect(self.displayCoordinator.isReady)

        self.stateTracker.currentState = .background
        #expect(!(self.displayCoordinator.isReady))

        self.stateTracker.currentState = .inactive
        #expect(!(self.displayCoordinator.isReady))
    }

    @Test
    func testIsReadyLocking() async throws {
        self.stateTracker.currentState = .active
        #expect(self.displayCoordinator.isReady)

        self.displayCoordinator.messageWillDisplay(fooSchedule)
        #expect(!(self.displayCoordinator.isReady))

        self.displayCoordinator.messageFinishedDisplaying(fooSchedule)
        await self.displayCoordinator.waitForReady()
        #expect(self.displayCoordinator.isReady)

        #expect([10] == self.taskSleeper.sleeps)
    }

    @Test
    func testWaitForReady() async throws {
        self.stateTracker.currentState = .background

        let ready = Task { [displayCoordinator] in
            await displayCoordinator.waitForReady()
        }

        self.stateTracker.currentState = .active
        await ready.value
    }

    @Test
    func testIsReadyOtherDisplayActive() throws {
        self.stateTracker.currentState = .active
        #expect(self.displayCoordinator.isReady)

        self.activityTracker.messageWillDisplay()
        #expect(!(self.displayCoordinator.isReady))

        self.activityTracker.messageWillDisplay()
        self.activityTracker.messageFinishedDisplaying()
        #expect(!(self.displayCoordinator.isReady))

        self.activityTracker.messageFinishedDisplaying()
        #expect(self.displayCoordinator.isReady)
    }

    @Test
    func testWaitForReadyOtherDisplayActive() async throws {
        self.stateTracker.currentState = .active
        self.activityTracker.messageWillDisplay()
        #expect(!(self.displayCoordinator.isReady))

        let ready = Task { [displayCoordinator] in
            await displayCoordinator.waitForReady()
        }

        self.activityTracker.messageFinishedDisplaying()
        await ready.value
        #expect(self.displayCoordinator.isReady)
    }
}
