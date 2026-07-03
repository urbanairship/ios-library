/* Copyright Airship and Contributors */

import Testing
@_spi(AirshipInternal) import AirshipBasement
import Foundation

@testable import AirshipCore

@Suite struct ChannelAuthTokenProviderTest {
    
    let client = TestChannelAuthTokenAPIClient()
    let channel = TestChannel()
    let channelID = "channel ID"
    let testDate = UATestDate(offset: 0, dateOverride: Date())
    var provider: ChannelAuthTokenProvider!
    
    init() {
        self.channel.identifier = "channel ID"
        self.provider = ChannelAuthTokenProvider(
            channel: channel,
            apiClient: client,
            date: testDate
        )
    }
    
    @Test
    func testFetchToken() async throws {
        self.client.handler = { channelId in
            let response = ChannelAuthTokenResponse(
                token: "my token",
                expiresInMillseconds: 100000
            )
            return AirshipHTTPResponse(
                result: response,
                statusCode: 200,
                headers: [:])
        }

        try await verifyToken(expected: "my token")
    }

    @Test
    func testTokenCached() async throws {
        self.client.handler = { channelId in
            let response = ChannelAuthTokenResponse(
                token: "my token",
                expiresInMillseconds: 100000
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

    @Test
    func testTokenCachedExpired() async throws {
        self.client.handler = { channelId in
            let response = ChannelAuthTokenResponse(
                token: "my token",
                expiresInMillseconds: 100000
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
                expiresInMillseconds: 100000
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


    private func verifyToken(expected: String, sourceLocation: SourceLocation = #_sourceLocation) async throws {
        let token = try await self.provider.resolveAuth(identifier: "channel ID")
        #expect(expected == token, sourceLocation: sourceLocation)
    }


    @Test
    func testTokenWithNilChannelID() async {
        self.channel.identifier = nil
        do {
            let _ = try await self.provider.resolveAuth(identifier: "channel ID")
            Issue.record("Should throw")
        } catch {}
    }


    @Test
    func testTokenMismatchChannelID() async {
        do {
            let _ = try await self.provider.resolveAuth(identifier: "some other channel ID")
            Issue.record("Should throw")
        } catch {}
    }

    @Test
    func testClientError() async {
        self.client.handler = { channelId in
            throw AirshipErrors.error("some error")
        }

        do {
            let _ = try await self.provider.resolveAuth(identifier: "some other channel ID")
            Issue.record("Should throw")
        } catch {}
    }
}
