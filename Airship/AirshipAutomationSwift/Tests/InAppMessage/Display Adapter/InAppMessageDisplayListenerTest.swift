/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipAutomationSwift
import AirshipCore


class InAppMessageDisplayListenerTests: XCTestCase {

    private let analytics: TestInAppMessageAnalytics = TestInAppMessageAnalytics()
    private var listener: InAppMessageDisplayListener!
    private let result: AirshipMainActorValue<DisplayResult?> = AirshipMainActorValue(nil)
    private var timer: TestActiveTimer!

    @MainActor
    override func setUp() {
        self.timer = TestActiveTimer()
        listener = InAppMessageDisplayListener(analytics: analytics, timer: timer) { [result] displayResult in
            result.set(displayResult)
        }
    }

    @MainActor
    func testOnDisplay() {
        XCTAssertFalse(timer.isStarted)

        listener.onDisplay()

        verifyEvents([InAppDisplayEvent()])
        XCTAssertTrue(timer.isStarted)

        listener.onDisplay()

        verifyEvents([InAppDisplayEvent()])
        XCTAssertNil(self.result.value)
    }

    @MainActor
    func testOnButtonDismissed() {
        self.timer.start()
        self.timer.time = 10

        let buttonInfo = InAppMessageButtonInfo(
            identifier: "button id",
            label: .init(text: "button label"),
            behavior: .dismiss
        )

        listener.onButtonDismissed(buttonInfo: buttonInfo)

        verifyEvents(
            [
                InAppResolutionEvent.buttonTap(
                    identifier: "button id",
                    description: "button label",
                    displayTime: 10
                )
            ]
        )

        XCTAssertFalse(timer.isStarted)
        XCTAssertEqual(self.result.value, .finished)
    }

    @MainActor
    func testOnButtonCancel() {
        self.timer.start()
        self.timer.time = 10

        let buttonInfo = InAppMessageButtonInfo(
            identifier: "button id",
            label: .init(text: "button label"),
            behavior: .cancel
        )

        listener.onButtonDismissed(buttonInfo: buttonInfo)

        verifyEvents(
            [
                InAppResolutionEvent.buttonTap(
                    identifier: "button id",
                    description: "button label",
                    displayTime: 10
                )
            ]
        )

        XCTAssertFalse(timer.isStarted)
        XCTAssertEqual(self.result.value, .cancel)
    }

    @MainActor
    func testOnTimedOut() {
        self.timer.start()
        self.timer.time = 3

        listener.onTimedOut()

        verifyEvents([InAppResolutionEvent.timedOut(displayTime: 3)])
        XCTAssertFalse(timer.isStarted)
        XCTAssertEqual(self.result.value, .finished)
    }

    @MainActor
    func testOnUserDismissed() {
        self.timer.start()
        self.timer.time = 3

        listener.onUserDismissed()

        verifyEvents([InAppResolutionEvent.userDismissed(displayTime: 3)])
        XCTAssertFalse(timer.isStarted)
        XCTAssertEqual(self.result.value, .finished)
    }

    @MainActor
    func testOnMessageTapDismissed() {
        self.timer.start()
        self.timer.time = 2

        listener.onMessageTapDismissed()

        verifyEvents([InAppResolutionEvent.messageTap(displayTime: 2)])
        XCTAssertEqual(self.result.value, .finished)
    }

    private func verifyEvents(_ expected: [InAppEvent], line: UInt = #line) {
        XCTAssertEqual(expected.count, self.analytics.events.count, line: line)

        expected.indices.forEach { index in
            let expectedEvent = expected[index]
            let event = analytics.events[index].0
            XCTAssertEqual(event.name, expectedEvent.name, line: line)
            XCTAssertEqual(try! AirshipJSON.wrap(event.data), try! AirshipJSON.wrap(expectedEvent.data), line: line)
        }
    }
}
