/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore

final class ChannelAuthTokenProviderTest: XCTestCase {
    
    var client = TestChannelAuthTokenAPIClient()
    var channel = TestChannel()
    var channelID = "channel ID"
    var testDate = UATestDate(offset: 0, dateOverride: Date())
    var provider: ChannelAuthTokenProvider!
    
    override func setUpWithError() throws {
        self.channel.identifier = "channel ID"
        self.provider = ChannelAuthTokenProvider(
            channel: channel,
            apiClient: client,
            date: testDate
        )
    }
    
    func testFetchToken() async throws {
        self.client.handler = { channelId in
            let response = ChannelAuthTokenResponse(
                token: "my token",
                expiresIn: 100.0
            )
            return AirshipHTTPResponse(
                result: response,
                statusCode: 200,
                headers: [:])
        }

        try await verifyToken(expected: "my token")
    }

    func testTokenCached() async throws {
        self.client.handler = { channelId in
            let response = ChannelAuthTokenResponse(
                token: "my token",
                expiresIn: 100.0
            )
            return AirshipHTTPResponse(
                result: response,
                statusCode: 200,
                headers: [:])
        }
        
        let _ = try await self.provider.resolveAuth(identifier: "channel ID")
        self.client.handler = { channelId in
            throw AirshipErrors.error("Failed")
        }

        // Should be cached
        try await verifyToken(expected: "my token")
    }

    func testTokenCachedExpired() async throws {
        self.client.handler = { channelId in
            let response = ChannelAuthTokenResponse(
                token: "my token",
                expiresIn: 100.0
            )
            return AirshipHTTPResponse(
                result: response,
                statusCode: 200,
                headers: [:])
        }

        let _ = try await self.provider.resolveAuth(identifier: "channel ID")
        self.client.handler = { channelId in
            let response = ChannelAuthTokenResponse(
                token: "some other token",
                expiresIn: 100.0
            )
            return AirshipHTTPResponse(
                result: response,
                statusCode: 200,
                headers: [:])
        }

        // Should be cached
        try await verifyToken(expected: "my token")
        testDate.offset += 70.0

        // 30 second buffer
        try await verifyToken(expected: "my token")
        testDate.offset += 1.0

        try await verifyToken(expected: "some other token")
    }


    private func verifyToken(expected: String, file: StaticString = #filePath, line: UInt = #line) async throws {
        let token = try await self.provider.resolveAuth(identifier: "channel ID")
        XCTAssertEqual(expected, token, file: file, line: line)
    }


    func testTokenWithNilChannelID() async {
        self.channel.identifier = nil
        do {
            let _ = try await self.provider.resolveAuth(identifier: "channel ID")
            XCTFail("Should throw")
        } catch {}
    }


    func testTokenMismatchChannelID() async {
        do {
            let _ = try await self.provider.resolveAuth(identifier: "some other channel ID")
            XCTFail("Should throw")
        } catch {}
    }

    func testClientError() async {
        self.client.handler = { channelId in
            throw AirshipErrors.error("some error")
        }

        do {
            let _ = try await self.provider.resolveAuth(identifier: "some other channel ID")
            XCTFail("Should throw")
        } catch {}
    }
}

