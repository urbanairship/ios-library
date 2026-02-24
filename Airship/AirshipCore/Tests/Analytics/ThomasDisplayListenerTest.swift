/* Copyright Airship and Contributors */

import Testing
@testable import AirshipCore


@MainActor
struct ThomasDisplayListenerTest {

    private let analytics = TestThomasLayoutMessageAnalytics()
    private let listener: ThomasDisplayListener
    private let result: AirshipMainActorValue<ThomasDisplayListener.DisplayResult?> = AirshipMainActorValue(nil)

    private let layoutContext: ThomasLayoutContext = ThomasLayoutContext(
        pager: nil,
        button: .init(identifier: "button"),
        form: nil
    )

    init() {
        self.listener = ThomasDisplayListener(
            analytics: analytics
        ) { [result] displayResult in
            result.set(displayResult)
        }
    }

    @Test
    func testDismiss() {
        listener.onDismissed(cancel: false)
        #expect(result.value == .finished)
    }

    @Test
    func testDismissAndCancel() {
        listener.onDismissed(cancel: true)
        #expect(result.value == .cancel)
    }

    @Test("Visibility changes emits display event")
    func testVisibilityChangesEmitsDisplayEvent() throws {
        listener.onVisibilityChanged(isVisible: true, isForegrounded: true)
        try verifyEvents([(ThomasLayoutDisplayEvent(), nil)])

        listener.onVisibilityChanged(isVisible: false, isForegrounded: false)
        try verifyEvents([(ThomasLayoutDisplayEvent(), nil)])

        listener.onVisibilityChanged(isVisible: true, isForegrounded: false)
        try verifyEvents([(ThomasLayoutDisplayEvent(), nil)])

        listener.onVisibilityChanged(isVisible: false, isForegrounded: true)
        try verifyEvents([(ThomasLayoutDisplayEvent(), nil)])

        listener.onVisibilityChanged(isVisible: true, isForegrounded: true)
        try verifyEvents([(ThomasLayoutDisplayEvent(), nil), (ThomasLayoutDisplayEvent(), nil)])
    }

    @Test
    func testButtonTapEvent() throws {
        let thomasEvent = ThomasReportingEvent.ButtonTapEvent(
            identifier: "button id",
            reportingMetadata: "some metadata"
        )

        listener.onReportingEvent(.buttonTap(thomasEvent, layoutContext))

        try verifyEvents(
            [
                (
                    ThomasLayoutButtonTapEvent(
                        data: thomasEvent
                    ),
                    self.layoutContext
                )
            ]
        )
    }

    @Test
    func testFormDisplayedEvent() throws {
        let thomasEvent = ThomasReportingEvent.FormDisplayEvent(
            identifier: "form id",
            formType: "some type"
        )

        listener.onReportingEvent(.formDisplay(thomasEvent, layoutContext))

        try verifyEvents(
            [
                (
                    ThomasLayoutFormDisplayEvent(data: thomasEvent),
                    self.layoutContext
                )
            ]
        )
    }

    @Test
    func testFormResultEvent() throws {
        let thomasEvent = ThomasReportingEvent.FormResultEvent(
            forms: try! AirshipJSON.wrap(["form": "result"])
        )

        listener.onReportingEvent(.formResult(thomasEvent, layoutContext))

        try verifyEvents(
            [
                (
                    ThomasLayoutFormResultEvent(data: thomasEvent),
                    self.layoutContext
                )
            ]
        )
    }

    @Test
    func testGestureEvent() throws {
        let thomasEvent = ThomasReportingEvent.GestureEvent(
            identifier: "gesture id",
            reportingMetadata: "some metadata"
        )

        listener.onReportingEvent(.gesture(thomasEvent, layoutContext))

        try verifyEvents(
            [
                (
                    ThomasLayoutGestureEvent(data: thomasEvent),
                    self.layoutContext
                )
            ]
        )
    }

    @Test
    func testPageActionEvent() throws {
        let thomasEvent = ThomasReportingEvent.PageActionEvent(
            identifier: "page id",
            reportingMetadata: "some metadata"
        )

        listener.onReportingEvent(.pageAction(thomasEvent, layoutContext))

        try verifyEvents(
            [
                (
                    ThomasLayoutPageActionEvent(data: thomasEvent),
                    self.layoutContext
                )
            ]
        )
    }

    @Test
    func testPagerCompletedEvent() throws {
        let thomasEvent = ThomasReportingEvent.PagerCompletedEvent(
            identifier: "pager id",
            pageIndex: 3,
            pageCount: 3,
            pageIdentifier: "page id"
        )

        listener.onReportingEvent(.pagerCompleted(thomasEvent, layoutContext))

        try verifyEvents(
            [
                (
                    ThomasLayoutPagerCompletedEvent(data: thomasEvent),
                    self.layoutContext
                )
            ]
        )
    }

    @Test
    func testPageSwipeEvent() throws {
        let thomasEvent = ThomasReportingEvent.PageSwipeEvent(
            identifier: "pager id",
            toPageIndex: 4,
            toPageIdentifier: "to page id",
            fromPageIndex: 3,
            fromPageIdentifier: "from page id"
        )
        listener.onReportingEvent(.pageSwipe(thomasEvent, layoutContext))

        try verifyEvents(
            [
                (
                    ThomasLayoutPageSwipeEvent(data: thomasEvent),
                    self.layoutContext
                )
            ]
        )
    }

    @Test
    func testPageViewEvent() throws {
        let thomasEvent = ThomasReportingEvent.PageViewEvent(
            identifier: "pager id",
            pageIdentifier: "page id",
            pageIndex: 1,
            pageViewCount: 1,
            pageCount: 3,
            completed: true
        )

        listener.onReportingEvent(.pageView(thomasEvent, layoutContext))

        try verifyEvents(
            [
                (
                    ThomasLayoutPageViewEvent(data: thomasEvent),
                    self.layoutContext
                )
            ]
        )
    }

    @Test
    func testPagerSummaryEvent() throws {
        let thomasEvent = ThomasReportingEvent.PagerSummaryEvent(
            identifier: "pager id",
            viewedPages: [
                .init(identifier: "foo", index: 1, displayTime: 10),
                .init(identifier: "bar", index: 2, displayTime: 10),
            ],
            pageCount: 3,
            completed: true
        )

        listener.onReportingEvent(.pagerSummary(thomasEvent, layoutContext))

        try verifyEvents(
            [
                (
                    ThomasLayoutPagerSummaryEvent(data: thomasEvent),
                    self.layoutContext
                )
            ]
        )
    }

    @MainActor
    func testUserDismissedEvent() throws {
        listener.onReportingEvent(
            ThomasReportingEvent.dismiss(.userDismissed, 10, layoutContext)
        )

        try verifyEvents(
            [(ThomasLayoutResolutionEvent.userDismissed(displayTime: 10), layoutContext)]
        )
    }


    @MainActor
    func testTimedOUtEvent() throws {
        listener.onReportingEvent(
            ThomasReportingEvent.dismiss(.timedOut, 10, layoutContext)
        )

        try verifyEvents(
            [(ThomasLayoutResolutionEvent.timedOut(displayTime: 10), layoutContext)]
        )
    }

    @MainActor
    func testDismissedEvent() throws {
        listener.onReportingEvent(
            ThomasReportingEvent.dismiss(
                .buttonTapped(
                    identifier: "button id",
                    description: "button description"
                ),
                10,
                layoutContext
            )
        )
        
        try verifyEvents(
            [
                (
                    ThomasLayoutResolutionEvent.buttonTap(
                        identifier: "button id",
                        description: "button description",
                        displayTime: 10),
                    layoutContext
                )
            ]
            
        )
    }

    private func verifyEvents(
        _ expected: [(ThomasLayoutEvent, ThomasLayoutContext?)],
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        #expect(expected.count == self.analytics.events.count, sourceLocation: sourceLocation)

        try expected.indices.forEach { index in
            let expectedEvent = expected[index]
            let actual = analytics.events[index]
            #expect(actual.0.name == expectedEvent.0.name, sourceLocation: sourceLocation)
            let actualData = try AirshipJSON.wrap(actual.0.data)
            let expectedData = try AirshipJSON.wrap(expectedEvent.0.data)
            #expect(actualData == expectedData, sourceLocation: sourceLocation)
            #expect(actual.1 == expectedEvent.1, sourceLocation: sourceLocation)
        }
    }
}

final class TestThomasLayoutMessageAnalytics: ThomasLayoutMessageAnalyticsProtocol, @unchecked Sendable {
    var events: [(ThomasLayoutEvent, ThomasLayoutContext?)] = []
    var impressionsRecored: UInt = 0
    func recordEvent(_ event: ThomasLayoutEvent, layoutContext: ThomasLayoutContext?) {
        events.append((event, layoutContext))
    }
}

