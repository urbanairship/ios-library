/* Copyright Airship and Contributors */

final class ChannelAuthTokenAPIClient: ChannelAuthTokenAPIClientProtocol, Sendable {
    private let tokenPath = "/api/auth/device"
    private let config: RuntimeConfig
    private let session: AirshipRequestSession

    init(
        config: RuntimeConfig,
        session: AirshipRequestSession
    ) {
        self.config = config
        self.session = session
    }

    convenience init(config: RuntimeConfig) {
        self.init(
            config: config,
            session: config.requestSession
        )
    }

    private func makeURL(path: String) throws -> URL {
        guard let deviceAPIURL = self.config.deviceAPIURL else {
            throw AirshipErrors.error("Initial config not resolved.")
        }

        let urlString = "\(deviceAPIURL)\(path)"

        guard let url = URL(string: "\(deviceAPIURL)\(path)") else {
            throw AirshipErrors.error("Invalid ChannelAPIClient URL: \(String(describing: urlString))")
        }

        return url
    }


    ///
    /// Retrieves the token associated with the provided channel ID.
    /// - Parameters:
    ///   - channelID: The channel ID.
    /// - Returns: AuthToken if succeed otherwise it throws an error
    func fetchToken(
        channelID: String
    ) async throws -> AirshipHTTPResponse<ChannelAuthTokenResponse> {
        let url = try makeURL(path: self.tokenPath)
        let request = AirshipRequest(
            url: url,
            headers: [
                "Accept": "application/vnd.urbanairship+json; version=3;",
            ],
            method: "GET",
            auth: .generatedChannelToken(identifier: channelID)
        )

        return try await session.performHTTPRequest(request) { data, response in
            
            AirshipLogger.debug("Channel auth token request finished with response: \(response)")

            guard response.statusCode == 200 else {
                return nil
            }

            return try AirshipJSONUtils.decode(data: data)
        }
    }
}

struct ChannelAuthTokenResponse: Decodable, Sendable {
    let token: String
    let expiresInMillseconds: UInt

    enum CodingKeys: String, CodingKey {
        case token = "token"
        case expiresInMillseconds = "expires_in"
    }
}

/// - Note: For internal use only. :nodoc:
protocol ChannelAuthTokenAPIClientProtocol: Sendable {
    func fetchToken(
        channelID: String
    ) async throws -> AirshipHTTPResponse<ChannelAuthTokenResponse>
}

