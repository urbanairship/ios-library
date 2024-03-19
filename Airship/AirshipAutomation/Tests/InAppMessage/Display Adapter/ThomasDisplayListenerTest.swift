/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipAutomation
import AirshipCore


class ThomasDisplayListenerTest: XCTestCase {

    private let analytics: TestInAppMessageAnalytics = TestInAppMessageAnalytics()
    private var listener: ThomasDisplayListener!
    private let result: AirshipMainActorValue<DisplayResult?> = AirshipMainActorValue(nil)
    private var timer: TestActiveTimer!

    private let layoutContext: ThomasLayoutContext = ThomasLayoutContext(
        formInfo: nil,
        pagerInfo: nil,
        buttonInfo: .init(identifier: "button")
    )

    @MainActor
    override func setUp() {
        self.timer = TestActiveTimer()
        let tracker = ThomasPagerTracker { [timer] in
            return timer!
        }

        listener = ThomasDisplayListener(
            analytics: analytics,
            tracker: tracker,
            timer: timer
        ) { [result] displayResult in
            result.set(displayResult)
        }
    }

    @MainActor
    func testOnVisibilityChanged() {
        XCTAssertFalse(timer.isStarted)

        listener.onVisbilityChanged(isVisible: true, isForegrounded: true)

        verifyEvents([(InAppDisplayEvent(), nil)])
        XCTAssertTrue(timer.isStarted)

        listener.onVisbilityChanged(isVisible: false, isForegrounded: false)
        verifyEvents([(InAppDisplayEvent(), nil)])
        XCTAssertFalse(timer.isStarted)

        listener.onVisbilityChanged(isVisible: true, isForegrounded: false)
        verifyEvents([(InAppDisplayEvent(), nil)])
        XCTAssertFalse(timer.isStarted)

        listener.onVisbilityChanged(isVisible: false, isForegrounded: true)
        verifyEvents([(InAppDisplayEvent(), nil)])
        XCTAssertFalse(timer.isStarted)


        listener.onVisbilityChanged(isVisible: true, isForegrounded: true)
        verifyEvents([(InAppDisplayEvent(), nil), (InAppDisplayEvent(), nil)])
        XCTAssertTrue(timer.isStarted)

        XCTAssertNil(self.result.value)
    }

    @MainActor
    func testFormSubmitted() {
        self.timer.start()

        let form = ThomasFormResult(identifier: "form id", formData: try! AirshipJSON.wrap(["form": "result"]))
        listener.onFormSubmitted(formResult: form, layoutContext: self.layoutContext)

        verifyEvents(
            [
                (
                    InAppFormResultEvent(forms: try! AirshipJSON.wrap(["form": "result"])),
                    self.layoutContext
                )
            ]
        )

        XCTAssertTrue(timer.isStarted)
        XCTAssertNil(self.result.value)
    }

    @MainActor
    func testFormDisplayed() {
        self.timer.start()

        let form = ThomasFormInfo(
            identifier: "form id",
            submitted: true,
            formType: "some type",
            formResponseType: "some response type"
        )
        listener.onFormDisplayed(formInfo: form, layoutContext: self.layoutContext)

        verifyEvents(
            [
                (
                    InAppFormDisplayEvent(formInfo: form),
                    self.layoutContext
                )
            ]
        )

        XCTAssertTrue(timer.isStarted)
        XCTAssertNil(self.result.value)
    }

    @MainActor
    func testButtonTap() {
        self.timer.start()

        listener.onButtonTapped(
            buttonIdentifier: "button id",
            metadata: .string("some metadata"),
            layoutContext: self.layoutContext
        )

        verifyEvents(
            [
                (
                    InAppButtonTapEvent(
                        identifier: "button id",
                        reportingMetadata: .string("some metadata")
                    ),
                    self.layoutContext
                )
            ]
        )

        XCTAssertTrue(timer.isStarted)
        XCTAssertNil(self.result.value)
    }

    @MainActor
    func testDismissed() {
        self.timer.start()
        self.timer.time = 10

        listener.onDismissed(layoutContext: nil)

        verifyEvents(
            [(InAppResolutionEvent.userDismissed(displayTime: 10), nil)]
        )

        XCTAssertFalse(timer.isStarted)
        XCTAssertEqual(self.result.value, .finished)
    }

    @MainActor
    func testDismissedWithContext() {
        self.timer.start()
        self.timer.time = 10

        listener.onDismissed(layoutContext: self.layoutContext)

        verifyEvents(
            [
                (
                    InAppResolutionEvent.userDismissed(displayTime: 10),
                    self.layoutContext
                )
            ]
        )

        XCTAssertFalse(timer.isStarted)
        XCTAssertEqual(self.result.value, .finished)
    }

    @MainActor
    func testButtonDismiss() {
        self.timer.start()
        self.timer.time = 10

        listener.onDismissed(
            buttonIdentifier: "button id",
            buttonDescription: "button description",
            cancel: false,
            layoutContext: self.layoutContext
        )

        verifyEvents(
            [
                (
                    InAppResolutionEvent.buttonTap(
                        identifier: "button id",
                        description: "button description",
                        displayTime: 10
                    ),
                    self.layoutContext
                )
            ]
        )

        XCTAssertFalse(timer.isStarted)
        XCTAssertEqual(self.result.value, .finished)
    }

    @MainActor
    func testButtonCancel() {
        self.timer.start()
        self.timer.time = 10

        listener.onDismissed(
            buttonIdentifier: "button id",
            buttonDescription: "button description",
            cancel: true,
            layoutContext: self.layoutContext
        )

        verifyEvents(
            [
                (
                    InAppResolutionEvent.buttonTap(
                        identifier: "button id",
                        description: "button description",
                        displayTime: 10
                    ),
                    self.layoutContext
                )
            ]
        )

        XCTAssertFalse(timer.isStarted)
        XCTAssertEqual(self.result.value, .cancel)
    }


    @MainActor
    func testOnTimeOut() {
        self.timer.start()
        self.timer.time = 10

        listener.onTimedOut(layoutContext: nil)

        verifyEvents(
            [
                (
                    InAppResolutionEvent.timedOut(displayTime: 10),
                    nil
                )
            ]
        )

        XCTAssertFalse(timer.isStarted)
        XCTAssertEqual(self.result.value, .finished)
    }

    @MainActor
    func testOnTimeOutWithContext() {
        self.timer.start()
        self.timer.time = 10

        listener.onTimedOut(layoutContext: self.layoutContext)

        verifyEvents(
            [
                (
                    InAppResolutionEvent.timedOut(displayTime: 10),
                    self.layoutContext
                )
            ]
        )

        XCTAssertFalse(timer.isStarted)
        XCTAssertEqual(self.result.value, .finished)
    }

    @MainActor
    func testPageView() {
        self.timer.start()

        let pagerInfo = makePagerInfo(pager: "foo", page: 0)

        listener.onPageViewed(
            pagerInfo: pagerInfo,
            layoutContext: self.layoutContext
        )

        verifyEvents(
            [
                (
                    InAppPageViewEvent(pagerInfo: pagerInfo, viewCount: 1),
                    self.layoutContext
                )
            ]
        )

        XCTAssertTrue(timer.isStarted)
        XCTAssertNil(self.result.value)
    }

    @MainActor
    func testPageGesture() {
        self.timer.start()

        listener.onPageGesture(
            identifier: "gesture id",
            metadata: .string("some metadata"),
            layoutContext: self.layoutContext
        )

        verifyEvents(
            [
                (
                    InAppGestureEvent(
                        identifier: "gesture id",
                        reportingMetadata: .string("some metadata")
                    ),
                    self.layoutContext
                )
            ]
        )

        XCTAssertTrue(timer.isStarted)
        XCTAssertNil(self.result.value)
    }

    @MainActor
    func testPageAction() {
        self.timer.start()

        listener.onPageAutomatedAction(
            identifier: "action id",
            metadata: .string("some metadata"),
            layoutContext: self.layoutContext
        )

        verifyEvents(
            [
                (
                    InAppPageActionEvent(
                        identifier: "action id",
                        reportingMetadata: .string("some metadata")
                    ),
                    self.layoutContext
                )
            ]
        )

        XCTAssertTrue(timer.isStarted)
        XCTAssertNil(self.result.value)
    }

    @MainActor
    func testPageSwipe() {
        self.timer.start()

        let from = makePagerInfo(pager: "foo", page: 0)
        let to = makePagerInfo(pager: "foo", page: 1)

        listener.onPageSwiped(
            from: from,
            to: to,
            layoutContext: self.layoutContext
        )

        verifyEvents(
            [
                (
                    InAppPageSwipeEvent(
                        from: from,
                        to: to
                    ),
                    self.layoutContext
                )
            ]
        )

        XCTAssertTrue(timer.isStarted)
        XCTAssertNil(self.result.value)
    }

    @MainActor
    func testPromptPermissionResult() {
        self.timer.start()


        listener.onPromptPermissionResult(
            permission: .displayNotifications,
            startingStatus: .denied,
            endingStatus: .granted,
            layoutContext: self.layoutContext
        )

        verifyEvents(
            [
                (
                    InAppPermissionResultEvent(
                        permission: .displayNotifications,
                        startingStatus: .denied,
                        endingStatus: .granted
                    ),
                    self.layoutContext
                )
            ]
        )

        XCTAssertTrue(timer.isStarted)
        XCTAssertNil(self.result.value)
    }

    @MainActor
    func testDismissPagerSummary() {
        self.timer.start()

        let page0 = makePagerInfo(pager: "foo", page: 0)
        let page1 = makePagerInfo(pager: "foo", page: 1)

        listener.onPageViewed(
            pagerInfo: page0,
            layoutContext: self.layoutContext
        )

        self.timer.time = 10
        listener.onPageViewed(
            pagerInfo: page1,
            layoutContext: self.layoutContext
        )

        self.timer.time = 20
        listener.onPageViewed(
            pagerInfo: page0,
            layoutContext: self.layoutContext
        )

        self.timer.time = 30
        listener.onDismissed(layoutContext: self.layoutContext)

        let expectedEvents: [(any InAppEvent, ThomasLayoutContext?)] = [
            (InAppPageViewEvent(pagerInfo: page0, viewCount: 1), self.layoutContext),
            (InAppPageViewEvent(pagerInfo: page1, viewCount: 1), self.layoutContext),
            (InAppPageViewEvent(pagerInfo: page0, viewCount: 2), self.layoutContext),
            (
                InAppPagerSummaryEvent(
                    pagerInfo: page0,
                    viewedPages: [
                        PageViewSummary(identifier: "page-0", index: 0, displayTime: 10),
                        PageViewSummary(identifier: "page-1", index: 1, displayTime: 20),
                        PageViewSummary(identifier: "page-0", index: 0, displayTime: 30)
                    ]
                ),
                self.layoutContext
            ),
            (InAppResolutionEvent.userDismissed(displayTime: 30), self.layoutContext)
        ]
        verifyEvents(expectedEvents)

        XCTAssertFalse(timer.isStarted)
        XCTAssertEqual(self.result.value, .finished)
    }


    private func verifyEvents(_ expected: [(InAppEvent, ThomasLayoutContext?)], line: UInt = #line) {
        XCTAssertEqual(expected.count, self.analytics.events.count, line: line)

        expected.indices.forEach { index in
            let expectedEvent = expected[index]
            let actual = analytics.events[index]
            XCTAssertEqual(actual.0.name, expectedEvent.0.name, line: line)
            XCTAssertEqual(try! AirshipJSON.wrap(actual.0.data), try! AirshipJSON.wrap(expectedEvent.0.data), line: line)
            XCTAssertEqual(actual.1, expectedEvent.1, line: line)
        }
    }

    private func makePagerInfo(pager: String, page: Int) -> ThomasPagerInfo {
        return ThomasPagerInfo(
           identifier: pager,
           pageIndex: page,
           pageIdentifier: "page-\(page)",
           pageCount: 100,
           completed: false
       )
    }
}
