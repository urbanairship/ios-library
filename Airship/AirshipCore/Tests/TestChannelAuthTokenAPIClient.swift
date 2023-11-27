/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipCore

final class TestChannelAuthTokenAPIClient: ChannelAuthTokenAPIClientProtocol, @unchecked Sendable {

    var handler: ((String) async throws -> AirshipHTTPResponse<ChannelAuthTokenResponse>)?

    func fetchToken(
        channelID: String
    ) async throws -> AirshipHTTPResponse<ChannelAuthTokenResponse> {

        guard let handler = handler else {
            throw AirshipErrors.error("Request block not set")
        }

        return try await handler(channelID)
    }

}
