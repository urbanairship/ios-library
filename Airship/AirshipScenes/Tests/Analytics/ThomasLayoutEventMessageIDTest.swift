/* Copyright Airship and Contributors */

import Foundation
import Testing

import AirshipCore
@testable @_spi(AirshipInternal) import AirshipSceneRenderer
@testable @_spi(AirshipInternal) import AirshipScenes

@Suite(.timeLimit(.minutes(1)))
struct ThomasLayoutEventMessageIDTest {

    private let campaigns = try! AirshipJSON.wrap(
        ["campaign1": "data1", "campaign2": "data2"]
    )

    private let scheduleID = UUID().uuidString

    @Test
    func legacy() async throws {
        let messageID = ThomasLayoutEventMessageID.legacy(identifier: scheduleID)

        let expectedJSON = """
           "\(scheduleID)"
        """

        let actual = try AirshipJSON.wrap(messageID)
        let expected = try AirshipJSON.from(json: expectedJSON)
        #expect(actual == expected)
    }

    @Test
    func appDefined() async throws {
        let messageID = ThomasLayoutEventMessageID.appDefined(identifier: scheduleID)

        let expectedJSON = """
           {
              "message_id": "\(scheduleID)"
           }
        """

        let actual = try AirshipJSON.wrap(messageID)
        let expected = try AirshipJSON.from(json: expectedJSON)
        #expect(actual == expected)
    }

    @Test
    func airship() async throws {
        let messageID = ThomasLayoutEventMessageID.airship(identifier: scheduleID, campaigns: campaigns)

        let expectedJSON = """
           {
              "message_id": "\(scheduleID)",
              "campaigns": \(try campaigns.toString()),
           }
        """

        let actual = try AirshipJSON.wrap(messageID)
        let expected = try AirshipJSON.from(json: expectedJSON)
        #expect(actual == expected)
    }

    @Test
    func airshipNoCampaigns() async throws {
        let messageID = ThomasLayoutEventMessageID.airship(identifier: scheduleID, campaigns: nil)

        let expectedJSON = """
           {
              "message_id": "\(scheduleID)"
           }
        """

        let actual = try AirshipJSON.wrap(messageID)
        let expected = try AirshipJSON.from(json: expectedJSON)
        #expect(actual == expected)
    }

    @Test
    func airshipWithSendMetadata() async throws {
        let messageID = ThomasLayoutEventMessageID.airship(
            identifier: scheduleID,
            campaigns: campaigns,
            sendMetadata: "encoded-send-metadata"
        )

        let expectedJSON = """
           {
              "message_id": "\(scheduleID)",
              "campaigns": \(try campaigns.toString()),
              "com.urbanairship.metadata": "encoded-send-metadata"
           }
        """

        let actual = try AirshipJSON.wrap(messageID)
        let expected = try AirshipJSON.from(json: expectedJSON)
        #expect(actual == expected)
    }

    @Test
    func airshipSendMetadataOmittedWhenNil() async throws {
        let messageID = ThomasLayoutEventMessageID.airship(
            identifier: scheduleID,
            campaigns: nil,
            sendMetadata: nil
        )

        let expectedJSON = """
           {
              "message_id": "\(scheduleID)"
           }
        """

        let actual = try AirshipJSON.wrap(messageID)
        let expected = try AirshipJSON.from(json: expectedJSON)
        #expect(actual == expected)
    }
}
