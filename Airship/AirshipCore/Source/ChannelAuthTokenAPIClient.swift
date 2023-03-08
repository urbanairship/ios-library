/* Copyright Airship and Contributors */

class ChannelAuthTokenAPIClient: ChannelAuthTokenAPIClientProtocol {
    private let tokenPath = "/api/auth/device"
    private let config: RuntimeConfig
    private let session: AirshipRequestSession
    private let decoder: JSONDecoder = JSONDecoder()

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
        let token = try AirshipUtils.generateSignedToken(
            secret: config.appSecret,
            tokenParams: [
                config.appKey,
                channelID
            ]
        )

        let request = AirshipRequest(
            url: url,
            headers: [
                "Accept": "application/vnd.urbanairship+json; version=3;",
                "X-UA-Channel-ID": channelID,
                "X-UA-App-Key": self.config.appKey
            ],
            method: "GET",
            auth: .bearer(token: token)
        )


        return try await session.performHTTPRequest(
            request
        ) { data, response in

            AirshipLogger.trace("Channel auth token request finished with status: \(response.statusCode)");

            guard response.statusCode == 200 else {
                return nil
            }

            let responseBody: ChannelAuthTokenResponse = try JSONUtils.decode(data: data)
            return responseBody
        }
    }
}

struct ChannelAuthTokenResponse: Decodable, Sendable {
    let token: String
    let expiresIn: TimeInterval

    enum CodingKeys: String, CodingKey {
        case token = "token"
        case expiresIn = "expires_in"
    }
}

/// - Note: For internal use only. :nodoc:
protocol ChannelAuthTokenAPIClientProtocol {
    func fetchToken(
        channelID: String
    ) async throws -> AirshipHTTPResponse<ChannelAuthTokenResponse>
}

