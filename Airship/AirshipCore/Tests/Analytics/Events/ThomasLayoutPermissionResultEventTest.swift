/* Copyright Airship and Contributors */

import Testing

@testable import AirshipCore


struct ThomasLayoutPermissionResultEventTest {

    @Test
    func testEvent() throws {
        let event = ThomasLayoutPermissionResultEvent(
            permission: .displayNotifications,
            startingStatus: .denied,
            endingStatus: .granted
        )
        #expect(event.name.reportingName == "in_app_permission_result")

        let expectedJSON = """
        {
           "permission":"display_notifications",
           "starting_permission_status":"denied",
           "ending_permission_status":"granted"
        }
        """

        let expected = try AirshipJSON.from(json: expectedJSON)
        let actual = try event.bodyJSON
        #expect(actual == expected)
    }

}
