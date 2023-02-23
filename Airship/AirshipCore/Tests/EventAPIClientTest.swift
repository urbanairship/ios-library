/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

final class EventAPIClientTest: XCTestCase {


    private let requestSession = TestAirshipRequestSession()
    private var client: EventAPIClient!

    private let eventData = [
        AirshipEventData.makeTestData()
    ]

    private let headers: [String: String] = [
        "some": "header"
    ]

    override func setUpWithError() throws {
        let config = AirshipConfig()
        config.requireInitialRemoteConfigEnabled = false
        let runtimeConfig = RuntimeConfig(
            config: config,
            dataStore: PreferenceDataStore(appKey: UUID().uuidString)
        )

        client = EventAPIClient(
            config: runtimeConfig,
            session: requestSession
        )
    }

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
            headers: self.headers
        )

        XCTAssertEqual(100, response.result!.maxBatchSizeKB)
        XCTAssertEqual(200, response.result!.maxTotalStoreSizeKB)
        XCTAssertEqual(10.4, response.result!.minBatchInterval)

    }

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
            headers: self.headers
        )

        XCTAssertNil(response.result!.maxBatchSizeKB)
        XCTAssertNil(response.result!.maxTotalStoreSizeKB)
        XCTAssertNil(response.result!.minBatchInterval)
    }

    func testUploadFailed() async throws {

        self.requestSession.response = HTTPURLResponse(
            url: URL(string: "https://www.airship.com")!,
            statusCode: 400,
            httpVersion: "",
            headerFields: [:]
        )

        let response = try await self.client.uploadEvents(
            self.eventData,
            headers: self.headers
        )

        XCTAssertNil(response.result!.maxBatchSizeKB)
        XCTAssertNil(response.result!.maxTotalStoreSizeKB)
        XCTAssertNil(response.result!.minBatchInterval)
    }
}
