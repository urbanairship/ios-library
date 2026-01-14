/* Copyright Airship and Contributors */

import Testing

@testable import AirshipCore

struct ThomasLayoutResolutionEventTest {

    @Test
    func testButtonResolution() throws {
        let event = ThomasLayoutResolutionEvent.buttonTap(
            identifier: "button id",
            description: "button description",
            displayTime: 100.0
        )
        #expect(event.name.reportingName == "in_app_resolution")

        let expectedJSON = """
        {
           "resolution": {
               "display_time":"100.00",
               "button_description":"button description",
               "type":"button_click",
               "button_id":"button id"
            }
        }
        """

        let expected = try AirshipJSON.from(json: expectedJSON)
        let actual = try event.bodyJSON
        #expect(actual == expected)
    }

    @Test
    func testMessageTap() throws {
        let event = ThomasLayoutResolutionEvent.messageTap(displayTime: 100.0)
        #expect(event.name.reportingName == "in_app_resolution")

        let expectedJSON = """
        {
           "resolution": {
               "display_time":"100.00",
               "type":"message_click"
            }
        }
        """

        let expected = try AirshipJSON.from(json: expectedJSON)
        let actual = try event.bodyJSON
        #expect(actual == expected)
    }

    @Test
    func testUserDismissed() throws {
        let event = ThomasLayoutResolutionEvent.userDismissed(displayTime: 100.0)
        #expect(event.name.reportingName == "in_app_resolution")

        let expectedJSON = """
        {
           "resolution": {
              "display_time":"100.00",
              "type":"user_dismissed"
           }
        }
        """

        let expected = try AirshipJSON.from(json: expectedJSON)
        let actual = try event.bodyJSON
        #expect(actual == expected)
    }

    @Test
    func testTimedOut() throws {
        let event = ThomasLayoutResolutionEvent.timedOut(displayTime: 100.0)
        #expect(event.name.reportingName == "in_app_resolution")

        let expectedJSON = """
        {
           "resolution": {
              "display_time":"100.00",
              "type":"timed_out"
           }
        }
        """

        let expected = try AirshipJSON.from(json: expectedJSON)
        let actual = try event.bodyJSON
        #expect(actual == expected)
    }

    @Test
    func testControl() throws {
        let experimentResult = ExperimentResult(
            channelID: "channel id",
            contactID: "contact id",
            isMatch: true,
            reportingMetadata: [AirshipJSON.string("reporting")]
        )

        let event = ThomasLayoutResolutionEvent.control(experimentResult: experimentResult)
        #expect(event.name.reportingName == "in_app_resolution")

        let expectedJSON = """
        {
           "resolution": {
              "display_time":"0.00",
              "type":"control"
           },
           "device": {
              "channel_id": "channel id",
              "contact_id": "contact id"
           }
        }
        """

        let expected = try AirshipJSON.from(json: expectedJSON)
        let actual = try event.bodyJSON
        #expect(actual == expected)
    }

    @Test
    func testAudienceExcluded() throws {
        let event = ThomasLayoutResolutionEvent.audienceExcluded()
        #expect(event.name.reportingName == "in_app_resolution")

        let expectedJSON = """
        {
           "resolution": {
              "display_time":"0.00",
              "type":"audience_check_excluded"
           }
        }
        """

        let expected = try AirshipJSON.from(json: expectedJSON)
        let actual = try event.bodyJSON
        #expect(actual == expected)
    }
}
