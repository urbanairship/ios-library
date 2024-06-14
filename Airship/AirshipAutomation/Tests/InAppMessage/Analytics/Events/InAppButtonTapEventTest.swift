/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipAutomation
@testable import AirshipCore

final class InAppButtonTapEventTest: XCTestCase {

    func testEvent() throws {
        let event = InAppButtonTapEvent(
            identifier: "button id",
            reportingMetadata: .string("reporting metadata")
        )

        let expectedJSON = """
        {
           "reporting_metadata":"reporting metadata",
           "button_identifier":"button id"
        }
        """

        XCTAssertEqual(event.name.reportingName, "in_app_button_tap")
        XCTAssertEqual(try event.bodyJSON, try! AirshipJSON.from(json: expectedJSON))
    }

}
