/* Copyright Airship and Contributors */

import Testing

@testable import AirshipAutomation
@testable import AirshipCore

struct InAppFormResultEventTest {

    @Test
    func testEvent() throws {
        let thomasEvent = ThomasReportingEvent.FormResultEvent(
            forms: .string("form result")
        )

        let event = InAppFormResultEvent(data: thomasEvent)
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
