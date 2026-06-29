/* Copyright Airship and Contributors */

import Testing

@testable import AirshipCore
@testable @_spi(AirshipInternal) import AirshipSceneRenderer
@testable @_spi(AirshipInternal) import AirshipScenes

struct ThomasLayoutDisplayEventTest {

    @Test
    func testEvent() throws {
        let event = ThomasLayoutDisplayEvent()
        #expect(event.name.reportingName == "in_app_display")
        #expect(event.data == nil)
    }

}
