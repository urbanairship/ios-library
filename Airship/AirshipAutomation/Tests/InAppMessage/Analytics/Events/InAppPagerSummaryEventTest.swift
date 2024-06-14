/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipAutomation
@testable import AirshipCore

final class InAppPagerSummaryEventTest: XCTestCase {

    func testEvent() throws {
        let event = InAppPagerSummaryEvent(
            pagerInfo: ThomasPagerInfo(
                identifier: "pager identifier",
                pageIndex: 3,
                pageIdentifier: "page identifier",
                pageCount: 12,
                completed: false
            ), viewedPages: [
                PageViewSummary(
                    identifier: "page 1",
                    index: 0,
                    displayTime: 10.4
                ),
                PageViewSummary(
                    identifier: "page 2",
                    index: 1,
                    displayTime: 3.0
                ),
                PageViewSummary(
                    identifier: "page 3",
                    index: 2,
                    displayTime: 4.0
                )
            ]
        )

        let expectedJSON = """
        {
           "viewed_pages":[
              {
                 "display_time":"10.40",
                 "page_identifier":"page 1",
                 "page_index":0
              },
              {
                 "page_index":1,
                 "display_time":"3.00",
                 "page_identifier":"page 2"
              },
              {
                 "page_identifier":"page 3",
                 "page_index":2,
                 "display_time":"4.00"
              }
           ],
           "page_count":12,
           "completed":false,
           "pager_identifier":"pager identifier"
        }
        """

        XCTAssertEqual(event.name.reportingName, "in_app_pager_summary")
        XCTAssertEqual(try event.bodyJSON, try! AirshipJSON.from(json: expectedJSON))
    }
}
