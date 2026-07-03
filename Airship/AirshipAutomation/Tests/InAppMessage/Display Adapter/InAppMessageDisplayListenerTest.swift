/* Copyright Airship and Contributors */

import Testing
@_spi(AirshipInternal) import AirshipBasement
import Foundation
@testable @_spi(AirshipInternal) import AirshipAutomation
import AirshipCore
@_spi(AirshipInternal) import AirshipScenes


@MainActor
struct InAppMessageDisplayListenerTests {

    private let analytics: TestInAppMessageAnalytics = TestInAppMessageAnalytics()
    private let listener: InAppMessageDisplayListener
    private let result: AirshipMainActorValue<DisplayResult?> = AirshipMainActorValue(nil)
    private let timer: TestActiveTimer

    init() {
        self.timer = TestActiveTimer()
        listener = InAppMessageDisplayListener(analytics: analytics, timer: timer) { [result] displayResult in
            result.set(displayResult)
        }
    }

    @Test
    func testOnAppear() async {
        #expect(!(timer.isStarted))

        listener.onAppear()

        verifyEvents([ThomasLayoutDisplayEvent()])
        #expect(timer.isStarted)

        listener.onAppear()

        verifyEvents([ThomasLayoutDisplayEvent(), ThomasLayoutDisplayEvent()])
        #expect(self.result.value == nil)
    }

    @Test
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
                ThomasLayoutResolutionEvent.buttonTap(
                    identifier: "button id",
                    description: "button label",
                    displayTime: 10
                )
            ]
        )

        #expect(!(timer.isStarted))
        #expect(self.result.value == .finished)
    }

    @Test
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
                ThomasLayoutResolutionEvent.buttonTap(
                    identifier: "button id",
                    description: "button label",
                    displayTime: 10
                )
            ]
        )

        #expect(!(timer.isStarted))
        #expect(self.result.value == .cancel)
    }

    @Test
    func testOnTimedOut() {
        self.timer.start()
        self.timer.time = 3

        listener.onTimedOut()

        verifyEvents([ThomasLayoutResolutionEvent.timedOut(displayTime: 3)])
        #expect(!(timer.isStarted))
        #expect(self.result.value == .finished)
    }

    @Test
    func testOnUserDismissed() {
        self.timer.start()
        self.timer.time = 3

        listener.onUserDismissed()

        verifyEvents([ThomasLayoutResolutionEvent.userDismissed(displayTime: 3)])
        #expect(!(timer.isStarted))
        #expect(self.result.value == .finished)
    }

    @Test
    func testOnMessageTapDismissed() {
        self.timer.start()
        self.timer.time = 2

        listener.onMessageTapDismissed()

        verifyEvents([ThomasLayoutResolutionEvent.messageTap(displayTime: 2)])
        #expect(self.result.value == .finished)
    }

    private func verifyEvents(_ expected: [ThomasLayoutEvent], sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(expected.count == self.analytics.events.count, sourceLocation: sourceLocation)

        expected.indices.forEach { index in
            let expectedEvent = expected[index]
            let event = analytics.events[index].0
            #expect(event.name == expectedEvent.name, sourceLocation: sourceLocation)
            #expect(try! AirshipJSON.wrap(event.data) == (try! AirshipJSON.wrap(expectedEvent.data)), sourceLocation: sourceLocation)
        }
    }
}
