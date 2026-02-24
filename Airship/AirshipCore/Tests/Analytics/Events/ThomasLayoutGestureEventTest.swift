/* Copyright Airship and Contributors */

import Testing

@testable import AirshipCore

struct ThomasLayoutGestureEventTest {

    @Test
    func testEvent() throws {
        let thomasEvent = ThomasReportingEvent.GestureEvent(
            identifier: "gesture id",
            reportingMetadata: "reporting metadata"
        )

        let event = ThomasLayoutGestureEvent(data: thomasEvent)
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
