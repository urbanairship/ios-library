/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable @_spi(AirshipInternal)
import AirshipAutomation
import AirshipCore

@MainActor
struct ImmediateDisplayCoordinatorTest {

    private let stateTracker: TestAppStateTracker = TestAppStateTracker()
    private let displayCoordinator: ImmediateDisplayCoordinator

    init() {
        displayCoordinator = ImmediateDisplayCoordinator(
            appStateTracker: self.stateTracker
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
    func testWaitForReady() async throws {
        self.stateTracker.currentState = .background

        let ready = Task { [displayCoordinator] in
            await displayCoordinator.waitForReady()
        }

        self.stateTracker.currentState = .active
        await ready.value
    }

    @Test
    func testDisplayMultiple() throws {
        self.stateTracker.currentState = .active

        let foo = InAppMessage(name: "foo", displayContent: .custom(.string("foo")))
        let bar = InAppMessage(name: "bar", displayContent: .custom(.string("bar")))


        self.displayCoordinator.messageWillDisplay(foo)
        #expect(self.displayCoordinator.isReady)


        self.displayCoordinator.messageWillDisplay(bar)
        #expect(self.displayCoordinator.isReady)

        self.displayCoordinator.messageFinishedDisplaying(foo)
        #expect(self.displayCoordinator.isReady)

        self.displayCoordinator.messageFinishedDisplaying(bar)
        #expect(self.displayCoordinator.isReady)
    }
}
