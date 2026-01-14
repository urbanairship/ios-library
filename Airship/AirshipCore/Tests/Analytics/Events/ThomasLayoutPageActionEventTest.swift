/* Copyright Airship and Contributors */

import Testing

@testable import AirshipCore

struct ThomasLayoutPageActionEventTest {

    @Test
    func testEvent() throws {
        let thomasEvent = ThomasReportingEvent.PageActionEvent(
            identifier: "action id",
            reportingMetadata: .string("reporting metadata")
        )

        let event = ThomasLayoutPageActionEvent(data: thomasEvent)
        #expect(event.name.reportingName == "in_app_page_action")

        let expectedJSON = """
        {
           "reporting_metadata":"reporting metadata",
           "action_identifier":"action id"
        }
        """

        let expected = try AirshipJSON.from(json: expectedJSON)
        let actual = try event.bodyJSON
        #expect(actual == expected)
    }

}
