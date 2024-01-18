/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipAutomationSwift
import AirshipCore

class InAppEventMessageIDTest: XCTestCase {

    private let campaigns = try! AirshipJSON.wrap(
        ["campaign1": "data1", "campaign2": "data2"]
    )

    private let scheduleID = UUID().uuidString


    func testLegacy() async throws {
        let messageID = InAppEventMessageID.legacy(identifier: scheduleID)

        let expectedJSON = """
           "\(scheduleID)"
        """

        XCTAssertEqual(try AirshipJSON.wrap(messageID), try AirshipJSON.from(json: expectedJSON))
    }

    func testAppDefined() async throws {
        let messageID = InAppEventMessageID.appDefined(identifier: scheduleID)

        let expectedJSON = """
           {
              "message_id": "\(scheduleID)"
           }
        """

        XCTAssertEqual(try AirshipJSON.wrap(messageID), try AirshipJSON.from(json: expectedJSON))
    }

    func testAirship() async throws {
        let messageID = InAppEventMessageID.airship(identifier: scheduleID, campaigns: self.campaigns)

        let expectedJSON = """
           {
              "message_id": "\(scheduleID)",
              "campaigns": \(try self.campaigns.toString()),
           }
        """

        XCTAssertEqual(try AirshipJSON.wrap(messageID), try AirshipJSON.from(json: expectedJSON))
    }

    func testAirshipNoCampaigns() async throws {
        let messageID = InAppEventMessageID.airship(identifier: scheduleID, campaigns: nil)

        let expectedJSON = """
           {
              "message_id": "\(scheduleID)"
           }
        """

        XCTAssertEqual(try AirshipJSON.wrap(messageID), try AirshipJSON.from(json: expectedJSON))
    }
}
