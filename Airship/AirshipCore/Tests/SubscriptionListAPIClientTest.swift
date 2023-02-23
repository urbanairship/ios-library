/* Copyright Airship and Contributors */

import SwiftUI
import XCTest

@testable import AirshipCore

class SubscriptionListAPIClientTest: XCTestCase {

    var config: RuntimeConfig!
    var session: TestAirshipRequestSession = TestAirshipRequestSession()
    var client: SubscriptionListAPIClient!

    override func setUpWithError() throws {
        let airshipConfig = AirshipConfig()
        airshipConfig.requireInitialRemoteConfigEnabled = false
        self.config = RuntimeConfig(
            config: airshipConfig,
            dataStore: PreferenceDataStore(appKey: UUID().uuidString)
        )
        self.client = SubscriptionListAPIClient(
            config: self.config,
            session: self.session
        )
    }

    func testGet() async throws {
        let responseBody = """
                {
                   "ok" : true,
                   "list_ids": ["example_listId-1","example_listId-2"]
                }
            """

        self.session.response = HTTPURLResponse(
            url: URL(string: "https://neat")!,
            statusCode: 200,
            httpVersion: "",
            headerFields: [String: String]()
        )
        self.session.data = responseBody.data(using: .utf8)

        let response = try await self.client.get(channelID: "some-channel")

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(
            ["example_listId-1", "example_listId-2"],
            response.result
        )

        XCTAssertEqual("GET", self.session.lastRequest?.method)
        XCTAssertEqual(
            "https://device-api.urbanairship.com/api/subscription_lists/channels/some-channel",
            self.session.lastRequest?.url?.absoluteString
        )
    }

    func testGetParseError() async throws {
        let responseBody = "What?"

        self.session.response = HTTPURLResponse(
            url: URL(string: "https://neat")!,
            statusCode: 200,
            httpVersion: "",
            headerFields: [String: String]()
        )
        self.session.data = responseBody.data(using: .utf8)


        do {
            _ = try await self.client.get(channelID: "some-channel")
            XCTFail("Should throw")
        } catch {
        }
    }

    func testGetError() async throws {
        let sessionError = AirshipErrors.error("error!")
        self.session.error = sessionError

        do {
            _ = try await self.client.get(channelID: "some-channel")
            XCTFail("Should throw")
        } catch {
            XCTAssertEqual(sessionError as NSError, error as NSError)
        }
    }
}
