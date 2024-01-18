/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipAutomationSwift
import AirshipCore

final class InAppGestureTapEventTest: XCTestCase {

    func testEvent() throws {
        let event = InAppGestureEvent(
            identifier: "gesture id",
            reportingMetadata: .string("reporting metadata")
        )

        let expectedJSON = """
        {
           "reporting_metadata":"reporting metadata",
           "gesture_identifier":"gesture id"
        }
        """

        XCTAssertEqual(event.name, "in_app_gesture")
        XCTAssertEqual(try event.bodyJSON, try! AirshipJSON.from(json: expectedJSON))
    }

}
