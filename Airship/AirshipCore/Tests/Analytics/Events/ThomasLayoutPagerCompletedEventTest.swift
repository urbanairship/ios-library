/* Copyright Airship and Contributors */

import Testing

@testable import AirshipCore

struct ThomasLayoutPagerCompletedEventTest {

    @Test
    func testEvent() throws {
        let thomasEvent = ThomasReportingEvent.PagerCompletedEvent(
            identifier: "pager identifier",
            pageIndex: 3,
            pageCount: 12,
            pageIdentifier: "page identifier"
        )

        let event = ThomasLayoutPagerCompletedEvent(data: thomasEvent)
        #expect(event.name.reportingName == "in_app_pager_completed")

        let expectedJSON = """
        {
           "page_count":12,
           "pager_identifier":"pager identifier",
           "page_index":3,
           "page_identifier":"page identifier"
        }
        """

        let expected = try AirshipJSON.from(json: expectedJSON)
        let actual = try event.bodyJSON
        #expect(actual == expected)
    }
}
