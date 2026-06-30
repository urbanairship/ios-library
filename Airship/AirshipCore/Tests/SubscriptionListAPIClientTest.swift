/* Copyright Airship and Contributors */

import SwiftUI
import Testing

@testable import AirshipCore
import Foundation

@Suite
struct SubscriptionListAPIClientTest {

    let config: RuntimeConfig = .testConfig()
    let session: TestAirshipRequestSession = TestAirshipRequestSession()
    let client: SubscriptionListAPIClient

    init() {
        self.client = SubscriptionListAPIClient(
            config: self.config,
            session: self.session
        )
    }

    @Test
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

        #expect(response.statusCode == 200)
        #expect(
            ["example_listId-1", "example_listId-2"] == response.result
        )

        #expect("GET" == self.session.lastRequest?.method)
        #expect(
            "https://device-api.urbanairship.com/api/subscription_lists/channels/some-channel" == self.session.lastRequest?.url?.absoluteString
        )
    }

    @Test
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
            Issue.record("Should throw")
        } catch {
        }
    }

    @Test
    func testGetError() async throws {
        let sessionError = AirshipErrors.error("error!")
        self.session.error = sessionError

        do {
            _ = try await self.client.get(channelID: "some-channel")
            Issue.record("Should throw")
        } catch {
            #expect(sessionError as NSError == error as NSError)
        }
    }
}
