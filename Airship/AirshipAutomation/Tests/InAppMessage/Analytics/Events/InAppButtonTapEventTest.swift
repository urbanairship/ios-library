/* Copyright Airship and Contributors */

import Testing

@testable import AirshipAutomation
@testable import AirshipCore

struct InAppButtonTapEventTest {

    @Test
    func testEvent() throws {
        let thomasEvent = ThomasReportingEvent.ButtonTapEvent(
            identifier: "button id",
            reportingMetadata: .string("reporting metadata")
        )

        let event = InAppButtonTapEvent(data: thomasEvent)
        #expect(event.name.reportingName == "in_app_button_tap")

        let expectedJSON = """
        {
           "reporting_metadata":"reporting metadata",
           "button_identifier":"button id"
        }
        """

        let expected = try AirshipJSON.from(json: expectedJSON)
        let actual = try event.bodyJSON
        #expect(actual == expected)
    }

}
