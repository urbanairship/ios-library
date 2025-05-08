/* Copyright Airship and Contributors */

import Testing

@testable import AirshipAutomation
@testable import AirshipCore

struct InAppPageViewEventTest {

    @Test
    func testEvent() throws {
        let thomasEvent = ThomasReportingEvent.PageViewEvent(
            identifier: "pager identifier",
            pageIdentifier: "page identifier",
            pageIndex: 3,
            pageViewCount: 31,
            pageCount: 12,
            completed: false
        )

        let event = InAppPageViewEvent(data: thomasEvent)
        #expect(event.name.reportingName == "in_app_page_view")

        let expectedJSON = """
        {
           "page_identifier":"page identifier",
           "page_index":3,
           "viewed_count":31,
           "page_count":12,
           "pager_identifier":"pager identifier",
           "completed":false
        }
        """

        let expected = try AirshipJSON.from(json: expectedJSON)
        let actual = try event.bodyJSON
        #expect(actual == expected)
    }

}
