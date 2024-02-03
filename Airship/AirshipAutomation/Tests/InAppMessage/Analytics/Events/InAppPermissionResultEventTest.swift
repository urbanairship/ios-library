/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipAutomation
import AirshipCore


final class InAppPermissionResultEventTest: XCTestCase {

    func testEvent() throws {
        let event = InAppPermissionResultEvent(
            permission: .displayNotifications,
            startingStatus: .denied,
            endingStatus: .granted
        )

        let expectedJSON = """
        {
           "permission":"display_notifications",
           "starting_permission_status":"denied",
           "ending_permission_status":"granted"
        }
        """

        XCTAssertEqual(event.name, "in_app_permission_result")
        XCTAssertEqual(try event.bodyJSON, try! AirshipJSON.from(json: expectedJSON))
    }

}
