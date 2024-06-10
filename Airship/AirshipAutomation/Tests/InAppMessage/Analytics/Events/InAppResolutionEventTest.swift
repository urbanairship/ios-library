/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipAutomation
@testable import AirshipCore

final class InAppResolutionEventTest: XCTestCase {
    
    func testButtonResolution() throws {
        let event = InAppResolutionEvent.buttonTap(
            identifier: "button id",
            description: "button description",
            displayTime: 100.0
        )

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

        XCTAssertEqual(event.name.reportingName, "in_app_resolution")
        XCTAssertEqual(try event.bodyJSON, try! AirshipJSON.from(json: expectedJSON))
    }

    func testMessageTap() throws {
        let event = InAppResolutionEvent.messageTap(displayTime: 100.0)

        let expectedJSON = """
        {
           "resolution": {
               "display_time":"100.00",
               "type":"message_click"
            }
        }
        """

        XCTAssertEqual(event.name.reportingName, "in_app_resolution")
        XCTAssertEqual(try event.bodyJSON, try! AirshipJSON.from(json: expectedJSON))
    }

    func testUserDismissed() throws {
        let event = InAppResolutionEvent.userDismissed(displayTime: 100.0)

        let expectedJSON = """
        {
           "resolution": {
              "display_time":"100.00",
              "type":"user_dismissed"
           }
        }
        """

        XCTAssertEqual(event.name.reportingName, "in_app_resolution")
        XCTAssertEqual(try event.bodyJSON, try! AirshipJSON.from(json: expectedJSON))
    }

    func testTimedOut() throws {
        let event = InAppResolutionEvent.timedOut(displayTime: 100.0)

        let expectedJSON = """
        {
           "resolution": {
              "display_time":"100.00",
              "type":"timed_out"
           }
        }
        """

        XCTAssertEqual(event.name.reportingName, "in_app_resolution")
        XCTAssertEqual(try event.bodyJSON, try! AirshipJSON.from(json: expectedJSON))
    }

    func testControl() throws {
        let experimentResult = ExperimentResult(
            channelID: "channel id",
            contactID: "contact id",
            isMatch: true,
            reportingMetadata: [AirshipJSON.string("reporting")]
        )

        let event = InAppResolutionEvent.control(experimentResult: experimentResult)

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

        XCTAssertEqual(event.name.reportingName, "in_app_resolution")
        XCTAssertEqual(try event.bodyJSON, try! AirshipJSON.from(json: expectedJSON))
    }

    func testAudienceExcluded() throws {

        let event = InAppResolutionEvent.audienceExcluded()

        let expectedJSON = """
        {
           "resolution": {
              "display_time":"0.00",
              "type":"audience_check_excluded"
           }
        }
        """

        XCTAssertEqual(event.name.reportingName, "in_app_resolution")
        XCTAssertEqual(try event.bodyJSON, try! AirshipJSON.from(json: expectedJSON))
    }
}
