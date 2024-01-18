/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipAutomationSwift
import AirshipCore

final class InAppFormDisplayEventTest: XCTestCase {

    func testEvent() throws {
        let event = InAppFormDisplayEvent(
            identifier: "form id",
            formType: "nps",
            responseType: "user feedback"
        )

        let expectedJSON = """
        {
           "form_identifier":"form id",
           "form_type":"nps",
           "form_response_type":"user feedback"
        }
        """

        XCTAssertEqual(event.name, "in_app_form_display")
        XCTAssertEqual(try event.bodyJSON, try! AirshipJSON.from(json: expectedJSON))
    }

}
