/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipAutomation
@testable import AirshipCore

final class InAppPageActionEventTest: XCTestCase {

    func testEvent() throws {
        let event = InAppPageActionEvent(
            identifier: "action id",
            reportingMetadata: .string("reporting metadata")
        )

        let expectedJSON = """
        {
           "reporting_metadata":"reporting metadata",
           "action_identifier":"action id"
        }
        """

        XCTAssertEqual(event.name.reportingName, "in_app_page_action")
        XCTAssertEqual(try event.bodyJSON, try! AirshipJSON.from(json: expectedJSON))
    }

}
