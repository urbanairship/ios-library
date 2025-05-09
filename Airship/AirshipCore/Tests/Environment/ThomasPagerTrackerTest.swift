/* Copyright Airship and Contributors */

import Testing
@testable import AirshipCore

@MainActor
struct ThomasPagerTrackerTest {

    private let tracker: ThomasPagerTracker = ThomasPagerTracker()
    
    @Test
    func testSummary() throws {
        let fooPage0 = makePageViewEvent(pager: "foo", page: 0)
        let fooPage1 = makePageViewEvent(pager: "foo", page: 1)
        let barPage0 = makePageViewEvent(pager: "bar", page: 0)
        let barPage1 = makePageViewEvent(pager: "bar", page: 1)

        #expect(self.tracker.summary.isEmpty)

        self.tracker.onPageView(pageEvent: fooPage0, currentDisplayTime: 0)
        #expect(
            self.tracker.summary == Set([
                ThomasReportingEvent.PagerSummaryEvent(
                    identifier: "foo",
                    viewedPages: [],
                    pageCount: fooPage0.pageCount,
                    completed: fooPage0.completed
                )
            ])
        )

        self.tracker.onPageView(pageEvent: fooPage1, currentDisplayTime: 10)
        #expect(
            self.tracker.summary == Set([
                ThomasReportingEvent.PagerSummaryEvent(
                    identifier: "foo",
                    viewedPages: [
                        .init(
                            identifier: "page-0",
                            index: 0,
                            displayTime: 10
                        )
                    ],
                    pageCount: fooPage0.pageCount,
                    completed: fooPage0.completed
                )
            ])
        )

        self.tracker.onPageView(pageEvent: barPage0, currentDisplayTime: 10)
        #expect(
            self.tracker.summary == Set([
                ThomasReportingEvent.PagerSummaryEvent(
                    identifier: "foo",
                    viewedPages: [
                        .init(
                            identifier: "page-0",
                            index: 0,
                            displayTime: 10
                        )
                    ],
                    pageCount: fooPage1.pageCount,
                    completed: fooPage1.completed
                ),
                ThomasReportingEvent.PagerSummaryEvent(
                    identifier: "bar",
                    viewedPages: [],
                    pageCount: barPage0.pageCount,
                    completed: barPage0.completed
                )
            ])
        )

        self.tracker.onPageView(pageEvent: fooPage0, currentDisplayTime: 20)
        #expect(
            self.tracker.summary == Set([
                ThomasReportingEvent.PagerSummaryEvent(
                    identifier: "foo",
                    viewedPages: [
                        .init(
                            identifier: "page-0",
                            index: 0,
                            displayTime: 10
                        ),
                        .init(
                            identifier: "page-1",
                            index: 1,
                            displayTime: 10
                        )
                    ],
                    pageCount: fooPage0.pageCount,
                    completed: fooPage0.completed
                ),
                ThomasReportingEvent.PagerSummaryEvent(
                    identifier: "bar",
                    viewedPages: [],
                    pageCount: barPage0.pageCount,
                    completed: barPage0.completed
                )
            ])
        )

        self.tracker.onPageView(pageEvent: barPage1, currentDisplayTime: 30)
        #expect(
            self.tracker.summary == Set([
                ThomasReportingEvent.PagerSummaryEvent(
                    identifier: "foo",
                    viewedPages: [
                        .init(
                            identifier: "page-0",
                            index: 0,
                            displayTime: 10
                        ),
                        .init(
                            identifier: "page-1",
                            index: 1,
                            displayTime: 10
                        )
                    ],
                    pageCount: fooPage0.pageCount,
                    completed: fooPage0.completed
                ),
                ThomasReportingEvent.PagerSummaryEvent(
                    identifier: "bar",
                    viewedPages: [
                        .init(
                            identifier: "page-0",
                            index: 0,
                            displayTime: 20
                        ),
                    ],
                    pageCount: barPage0.pageCount,
                    completed: barPage0.completed
                )
            ])
        )

        self.tracker.stopAll(currentDisplayTime: 40)
        #expect(
            self.tracker.summary == Set([
                ThomasReportingEvent.PagerSummaryEvent(
                    identifier: "foo",
                    viewedPages: [
                        .init(
                            identifier: "page-0",
                            index: 0,
                            displayTime: 10
                        ),
                        .init(
                            identifier: "page-1",
                            index: 1,
                            displayTime: 10
                        ),
                        .init(
                            identifier: "page-0",
                            index: 0, displayTime: 20
                        )
                    ],
                    pageCount: fooPage0.pageCount,
                    completed: fooPage0.completed
                ),
                ThomasReportingEvent.PagerSummaryEvent(
                    identifier: "bar",
                    viewedPages: [
                        .init(
                            identifier: "page-0",
                            index: 0,
                            displayTime: 20
                        ),
                        .init(
                            identifier: "page-1",
                            index: 1,
                            displayTime: 10
                        )
                    ],
                    pageCount: barPage0.pageCount,
                    completed: barPage0.completed
                )
            ])
        )
    }

    @Test
    func testViewedPages() throws {
        self.tracker.onPageView(
            pageEvent: makePageViewEvent(pager: "foo", page: 0),
            currentDisplayTime: 0
        )

        self.tracker.onPageView(
            pageEvent: makePageViewEvent(pager: "foo", page: 1),
            currentDisplayTime: 1
        )

        self.tracker.onPageView(
            pageEvent: makePageViewEvent(pager: "bar", page: 0),
            currentDisplayTime: 1
        )

        self.tracker.onPageView(
            pageEvent: makePageViewEvent(pager: "foo", page: 2),
            currentDisplayTime: 4
        )

        #expect(
            self.tracker.viewedPages(pagerIdentifier: "foo") == [
                .init(
                    identifier: "page-0",
                    index: 0,
                    displayTime: 1
                ),
                .init(
                    identifier: "page-1",
                    index: 1,
                    displayTime: 3
                )
            ]
        )

        // Still on page 0 so its empty
        #expect(self.tracker.viewedPages(pagerIdentifier: "bar") == [])

        // Baz does not exist
        #expect(self.tracker.viewedPages(pagerIdentifier: "baz") == [])
    }

    private func makePageViewEvent(pager: String, page: Int) -> ThomasReportingEvent.PageViewEvent {
        return ThomasReportingEvent.PageViewEvent(
           identifier: pager,
           pageIdentifier: "page-\(page)",
           pageIndex: page,
           pageViewCount: 1,
           pageCount: 100,
           completed: false
       )
    }

}
