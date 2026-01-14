/* Copyright Airship and Contributors */

import Testing

@testable import AirshipCore

struct ThomasLayoutPagerSummaryEventTest {

    func testEvent() throws {
        let event = ThomasLayoutPagerSummaryEvent(
            data: .init(
                identifier: "pager identifier",
                viewedPages: [
                    .init(
                        identifier: "page 1",
                        index: 0,
                        displayTime: 10.4
                    ),
                    .init(
                        identifier: "page 2",
                        index: 1,
                        displayTime: 3.0
                    ),
                    .init(
                        identifier: "page 3",
                        index: 2,
                        displayTime: 4.0
                    )
                ],
                pageCount: 12,
                completed: false
            )
        )
        #expect(event.name.reportingName == "in_app_pager_summary")

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

        let expected = try AirshipJSON.from(json: expectedJSON)
        let actual = try event.bodyJSON
        #expect(actual == expected)
    }
}
