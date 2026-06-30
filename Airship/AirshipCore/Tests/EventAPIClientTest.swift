/* Copyright Airship and Contributors */

import Testing

@testable
import AirshipCore
import Foundation

@Suite struct EventAPIClientTest {
    private let requestSession = TestAirshipRequestSession()
    private let client: EventAPIClient

    private let eventData = [
        AirshipEventData.makeTestData()
    ]

    private let headers: [String: String] = [
        "some": "header"
    ]

    init() throws {
        client = EventAPIClient(
            config: .testConfig(),
            session: requestSession
        )
    }

    @Test
    func testUpload() async throws {
        let responseHeaders = [
            "X-UA-Max-Total": "200",
            "X-UA-Max-Batch": "100",
            "X-UA-Min-Batch-Interval": "10.4"
        ]

        self.requestSession.response = HTTPURLResponse(
            url: URL(string: "https://www.airship.com")!,
            statusCode: 200,
            httpVersion: "",
            headerFields: responseHeaders
        )

        let response = try await self.client.uploadEvents(
            self.eventData,
            channelID: "some channel",
            headers: self.headers
        )

        #expect(100 == response.result!.maxBatchSizeKB)
        #expect(200 == response.result!.maxTotalStoreSizeKB)
        #expect(10.4 == response.result!.minBatchInterval)
        #expect(self.requestSession.lastRequest?.auth == .channelAuthToken(identifier: "some channel"))


    }

    @Test
    func testUploadBadHeaders() async throws {
        let responseHeaders = [
            "X-UA-Max-Total": "string",
            "X-UA-Max-Batch": "true",
        ]

        self.requestSession.response = HTTPURLResponse(
            url: URL(string: "https://www.airship.com")!,
            statusCode: 200,
            httpVersion: "",
            headerFields: responseHeaders
        )

        let response = try await self.client.uploadEvents(
            self.eventData,
            channelID: "some channel",
            headers: self.headers
        )

        #expect(response.result!.maxBatchSizeKB == nil)
        #expect(response.result!.maxTotalStoreSizeKB == nil)
        #expect(response.result!.minBatchInterval == nil)
    }

    @Test
    func testUploadFailed() async throws {

        self.requestSession.response = HTTPURLResponse(
            url: URL(string: "https://www.airship.com")!,
            statusCode: 400,
            httpVersion: "",
            headerFields: [:]
        )

        let response = try await self.client.uploadEvents(
            self.eventData,
            channelID: "some channel",
            headers: self.headers
        )

        #expect(response.result!.maxBatchSizeKB == nil)
        #expect(response.result!.maxTotalStoreSizeKB == nil)
        #expect(response.result!.minBatchInterval == nil)
    }
}
