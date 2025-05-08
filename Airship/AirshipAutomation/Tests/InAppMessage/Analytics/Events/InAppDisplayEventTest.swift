/* Copyright Airship and Contributors */

import Testing

@testable import AirshipAutomation
@testable import AirshipCore

struct InAppDisplayEventTest {

    @Test
    func testEvent() throws {
        let event = InAppDisplayEvent()
        #expect(event.name.reportingName == "in_app_display")
        #expect(event.data == nil)
    }

}
