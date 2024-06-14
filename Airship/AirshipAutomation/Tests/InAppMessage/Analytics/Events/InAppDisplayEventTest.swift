/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipAutomation
@testable import AirshipCore

final class InAppDisplayEventTest: XCTestCase {
    func testEvent() throws {
        let event = InAppDisplayEvent()
        XCTAssertEqual(event.name.reportingName, "in_app_display")
        XCTAssertNil(event.data)
    }
}
