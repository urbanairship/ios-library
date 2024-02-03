/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipAutomation
import AirshipCore

final class ImmediateDisplayCoordinatorTest: XCTestCase {

    private let stateTracker: TestAppStateTracker = TestAppStateTracker()
    private var displayCoordinator: ImmediateDisplayCoordinator!

    @MainActor
    override func setUp() async throws {
        displayCoordinator = ImmediateDisplayCoordinator(
            appStateTracker: self.stateTracker
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
    func testWaitForReady() async throws {
        self.stateTracker.currentState = .background

        let ready = Task { [displayCoordinator] in
            await displayCoordinator!.waitForReady()
        }

        self.stateTracker.currentState = .active
        await ready.value
    }

    @MainActor
    func testDisplayMultiple() throws {
        self.stateTracker.currentState = .active

        let foo = InAppMessage(name: "foo", displayContent: .custom(.string("foo")))
        let bar = InAppMessage(name: "bar", displayContent: .custom(.string("bar")))


        self.displayCoordinator.messageWillDisplay(foo)
        XCTAssertTrue(self.displayCoordinator.isReady)


        self.displayCoordinator.messageWillDisplay(bar)
        XCTAssertTrue(self.displayCoordinator.isReady)

        self.displayCoordinator.messageFinishedDisplaying(foo)
        XCTAssertTrue(self.displayCoordinator.isReady)

        self.displayCoordinator.messageFinishedDisplaying(bar)
        XCTAssertTrue(self.displayCoordinator.isReady)
    }
}
