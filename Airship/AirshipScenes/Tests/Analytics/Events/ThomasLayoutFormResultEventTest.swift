/* Copyright Airship and Contributors */

import Testing

@testable import AirshipCore
@testable @_spi(AirshipInternal) import AirshipSceneRenderer
@testable @_spi(AirshipInternal) import AirshipScenes

struct ThomasLayoutFormResultEventTest {

    @Test
    func testEvent() throws {
        let thomasEvent = ThomasReportingEvent.FormResultEvent(
            forms: "form result"
        )

        let event = ThomasLayoutFormResultEvent(data: thomasEvent)
        #expect(event.name.reportingName == "in_app_form_result")

        let expectedJSON = """
        {
           "forms": "form result"
        }
        """
        
        let expected = try AirshipJSON.from(json: expectedJSON)
        let actual = try event.bodyJSON
        #expect(actual == expected)
    }
}
