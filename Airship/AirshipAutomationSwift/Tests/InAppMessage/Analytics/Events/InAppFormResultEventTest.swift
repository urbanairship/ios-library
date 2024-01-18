/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipAutomationSwift
import AirshipCore

final class InAppFormResultEventTest: XCTestCase {

    func testEvent() throws {
        let event = InAppFormResultEvent(
            forms: .string("form result")
        )

        let expectedJSON = """
        {
           "forms": "form result"
        }
        """

        XCTAssertEqual(event.name, "in_app_form_result")
        XCTAssertEqual(try event.bodyJSON, try! AirshipJSON.from(json: expectedJSON))
    }

}
