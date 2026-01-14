/* Copyright Airship and Contributors */

import Testing

@testable import AirshipCore

struct ThomasLayoutFormDisplayEventTest {

    @Test
    func testEvent() throws {
        let thomasEvent = ThomasReportingEvent.FormDisplayEvent(
            identifier: "form id",
            formType: "nps",
            responseType: "user feedback"
        )

        let event = ThomasLayoutFormDisplayEvent(data: thomasEvent)
        #expect(event.name.reportingName == "in_app_form_display")

        let expectedJSON = """
        {
           "form_identifier":"form id",
           "form_type":"nps",
           "form_response_type":"user feedback"
        }
        """

        let expected = try AirshipJSON.from(json: expectedJSON)
        let actual = try event.bodyJSON
        #expect(actual == expected)
    }

}
