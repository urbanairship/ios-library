/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipAutomation
import AirshipCore

final class ThomasPagerTrackerTest: XCTestCase {

    private var tracker: ThomasPagerTracker!
    private var timer: TestActiveTimer!

    override func setUp() async throws {
        self.timer = await TestActiveTimer()
        self.tracker = await ThomasPagerTracker { [timer] in
            return timer!
        }
    }

    @MainActor
    func testViewCount() throws {
        let fooPage0 = makePagerInfo(pager: "foo", page: 0)
        let fooPage1 = makePagerInfo(pager: "foo", page: 1)
        let barPage0 = makePagerInfo(pager: "bar", page: 0)

        XCTAssertEqual(self.tracker.viewCount(pagerInfo: fooPage0), 0)
        XCTAssertEqual(self.tracker.viewCount(pagerInfo: fooPage1), 0)
        XCTAssertEqual(self.tracker.viewCount(pagerInfo: barPage0), 0)

        self.tracker.onPageView(pagerInfo: fooPage0)

        XCTAssertEqual(self.tracker.viewCount(pagerInfo: fooPage0), 1)
        XCTAssertEqual(self.tracker.viewCount(pagerInfo: fooPage1), 0)
        XCTAssertEqual(self.tracker.viewCount(pagerInfo: barPage0), 0)

        self.tracker.onPageView(pagerInfo: fooPage1)

        XCTAssertEqual(self.tracker.viewCount(pagerInfo: fooPage0), 1)
        XCTAssertEqual(self.tracker.viewCount(pagerInfo: fooPage1), 1)
        XCTAssertEqual(self.tracker.viewCount(pagerInfo: barPage0), 0)

        self.tracker.onPageView(pagerInfo: barPage0)
        self.tracker.onPageView(pagerInfo: fooPage0)

        XCTAssertEqual(self.tracker.viewCount(pagerInfo: fooPage0), 2)
        XCTAssertEqual(self.tracker.viewCount(pagerInfo: fooPage1), 1)
        XCTAssertEqual(self.tracker.viewCount(pagerInfo: barPage0), 1)

        self.tracker.stopAll()

        XCTAssertEqual(self.tracker.viewCount(pagerInfo: fooPage0), 2)
        XCTAssertEqual(self.tracker.viewCount(pagerInfo: fooPage1), 1)
        XCTAssertEqual(self.tracker.viewCount(pagerInfo: barPage0), 1)
    }

    @MainActor
    func testSummary() throws {
        let fooPage0 = makePagerInfo(pager: "foo", page: 0)
        let fooPage1 = makePagerInfo(pager: "foo", page: 1)
        let barPage0 = makePagerInfo(pager: "bar", page: 0)
        let barPage1 = makePagerInfo(pager: "bar", page: 1)

        XCTAssertEqual(self.tracker.summary, [:])

        self.tracker.onPageView(pagerInfo: fooPage0)
        XCTAssertEqual(
            self.tracker.summary,
            [
                fooPage0: []
            ]
        )

        self.timer.time = 10
        self.tracker.onPageView(pagerInfo: fooPage1)

        XCTAssertEqual(
            self.tracker.summary,
            [
                fooPage1: [
                    PageViewSummary(identifier: "page-0", index: 0, displayTime: 10)
                ]
            ]
        )


        self.tracker.onPageView(pagerInfo: barPage0)
        XCTAssertEqual(
            self.tracker.summary,
            [
                barPage0: [],
                fooPage1: [
                    PageViewSummary(identifier: "page-0", index: 0, displayTime: 10)
                ]
            ]
        )

        self.timer.time = 20
        self.tracker.onPageView(pagerInfo: fooPage0)
        XCTAssertEqual(
            self.tracker.summary,
            [
                barPage0: [],
                fooPage0: [
                    PageViewSummary(identifier: "page-0", index: 0, displayTime: 10),
                    PageViewSummary(identifier: "page-1", index: 1, displayTime: 20)
                ]
            ]
        )

        self.timer.time = 30
        self.tracker.onPageView(pagerInfo: barPage1)
        XCTAssertEqual(
            self.tracker.summary,
            [
                barPage1: [
                    PageViewSummary(identifier: "page-0", index: 0, displayTime: 30),
                ],
                fooPage0: [
                    PageViewSummary(identifier: "page-0", index: 0, displayTime: 10),
                    PageViewSummary(identifier: "page-1", index: 1, displayTime: 20)
                ]
            ]
        )

        self.timer.time = 40
        self.tracker.stopAll()
        XCTAssertEqual(
            self.tracker.summary,
            [
                barPage1: [
                    PageViewSummary(identifier: "page-0", index: 0, displayTime: 30),
                    PageViewSummary(identifier: "page-1", index: 1, displayTime: 40),
                ],
                fooPage0: [
                    PageViewSummary(identifier: "page-0", index: 0, displayTime: 10),
                    PageViewSummary(identifier: "page-1", index: 1, displayTime: 20),
                    PageViewSummary(identifier: "page-0", index: 0, displayTime: 40),
                ]
            ]
        )


        XCTAssertEqual(self.tracker.viewCount(pagerInfo: fooPage0), 2)
        XCTAssertEqual(self.tracker.viewCount(pagerInfo: fooPage1), 1)
        XCTAssertEqual(self.tracker.viewCount(pagerInfo: barPage0), 1)
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


