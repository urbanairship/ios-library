/* Copyright Airship and Contributors */

import Testing

@testable import AirshipAutomation
@testable import AirshipCore

struct InAppGestureTapEventTest {

    @Test
    func testEvent() throws {
        let thomasEvent = ThomasReportingEvent.GestureEvent(
            identifier: "gesture id",
            reportingMetadata: .string("reporting metadata")
        )

        let event = InAppGestureEvent(data: thomasEvent)
        #expect(event.name.reportingName == "in_app_gesture")

        let expectedJSON = """
        {
           "reporting_metadata":"reporting metadata",
           "gesture_identifier":"gesture id"
        }
        """

        let expected = try AirshipJSON.from(json: expectedJSON)
        let actual = try event.bodyJSON
        #expect(actual == expected)
    }

}
