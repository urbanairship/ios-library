/* Copyright Airship and Contributors */

import Testing

@testable import AirshipAutomation
@testable import AirshipCore

struct InAppPageSwipeEventAction {

    @Test
    func testEvent() throws {
        let thomasEvent = ThomasReportingEvent.PageSwipeEvent(
            identifier: "pager identifier",
            toPageIndex: 4,
            toPageIdentifier: "to page identifier",
            fromPageIndex: 3,
            fromPageIdentifier: "from page identifier"
        )

        let event = InAppPageSwipeEvent(data: thomasEvent)
        #expect(event.name.reportingName == "in_app_page_swipe")

        let expectedJSON = """
        {
           "pager_identifier":"pager identifier",
           "from_page_index":3,
           "to_page_identifier":"to page identifier",
           "from_page_identifier":"from page identifier",
           "to_page_index":4
        }
        """

        let expected = try AirshipJSON.from(json: expectedJSON)
        let actual = try event.bodyJSON
        #expect(actual == expected)
    }

}
