/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipAutomationSwift
import AirshipCore

final class InAppDisplayEventTest: XCTestCase {
    func testEvent() throws {
        let event = InAppDisplayEvent()
        XCTAssertEqual(event.name, "in_app_display")
        XCTAssertNil(event.data)
    }
}
