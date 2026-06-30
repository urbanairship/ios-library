/* Copyright Airship and Contributors */

import Testing

@testable import AirshipCore
import Foundation

@Suite struct ChannelAuthTokenAPIClientTest {

    let config = RuntimeConfig.testConfig()
    private let session = TestAirshipRequestSession()
    private let client: ChannelAuthTokenAPIClient

    init() {
        self.client = ChannelAuthTokenAPIClient(
            config: self.config,
            session: self.session
        )
    }

    @Test
    func testTokenWithChannelID() async throws {
        self.session.data = (try? AirshipJSON.wrap([
            "token": "abc123",
            "expires_in": 12345
        ] as [String : Any]).toData()) ?? Data()
        self.session.response = HTTPURLResponse(
            url: URL(string: "https://www.linkedin.com/")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)

        _ = try await self.client.fetchToken(channelID: "channel ID")

        let request = try #require(self.session.lastRequest)

        #expect(request.method == "GET")
        #expect(request.url!.absoluteString == "\(self.config.deviceAPIURL!)/api/auth/device")
        #expect(
            AirshipRequestAuth.generatedChannelToken(identifier: "channel ID") ==
            request.auth
        )
        #expect(request.headers["Accept"] == "application/vnd.urbanairship+json; version=3;")
    }

    @Test
    func testTokenWithChannelIDMalformedPayload() async throws {
        self.session.data = (try? AirshipJSON.wrap([
            "not a token": "abc123",
            "expires_in_3_2_1": 12345
        ] as [String : Any]).toData()) ?? Data()
        self.session.response = HTTPURLResponse(
            url: URL(string: "https://www.linkedin.com/")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)

        do {
            let _ = try await self.client.fetchToken(channelID: "channel ID")
            Issue.record("Should throw")
        } catch {}

    }

    @Test
    func testTokenWithChannelIDClientError() async throws {
        self.session.data = (try? AirshipJSON.wrap([
            "too": "bad"
        ]).toData()) ?? Data()
        self.session.response = HTTPURLResponse(
            url: URL(string: "https://www.linkedin.com/")!,
            statusCode: 400,
            httpVersion: nil,
            headerFields: nil)

        let unwrapResponse = try await self.client.fetchToken(channelID: "channel ID")
        #expect(unwrapResponse.result?.token == nil)
        #expect(unwrapResponse.isClientError)
        #expect(!(unwrapResponse.isSuccess))
    }
}
