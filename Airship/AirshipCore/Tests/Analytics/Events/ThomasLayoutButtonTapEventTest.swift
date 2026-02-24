/* Copyright Airship and Contributors */

import Testing

@testable import AirshipCore

struct ThomasLayoutButtonTapEventTest {

    @Test
    func testEvent() throws {
        let thomasEvent = ThomasReportingEvent.ButtonTapEvent(
            identifier: "button id",
            reportingMetadata: "reporting metadata"
        )

        let event = ThomasLayoutButtonTapEvent(data: thomasEvent)
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
