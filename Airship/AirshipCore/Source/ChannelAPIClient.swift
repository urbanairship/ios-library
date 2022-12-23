/* Copyright Airship and Contributors */

/// - Note: For internal use only. :nodoc:
class ChannelAPIClient: ChannelAPIClientProtocol {
    private let path = "/api/channels/"

    private let config: RuntimeConfig
    private let session: AirshipRequestSession
    private let encoder: JSONEncoder = JSONEncoder()

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
            session: AirshipRequestSession(appKey: config.appKey)
        )
    }

    private func makeURL(channelID: String? = nil) throws -> URL {
        guard let deviceAPIURL = self.config.deviceAPIURL else {
            throw AirshipErrors.error("Initial config not resolved.")
        }
        var urlString: String?
        if let channelID = channelID {
            urlString = "\(deviceAPIURL)\(self.path)\(channelID)"
        } else {
            urlString = "\(deviceAPIURL)\(self.path)"
        }

        guard let urlString = urlString,
              let url = URL(string: urlString)
        else {
            throw AirshipErrors.error("Invalid channel URL: \(String(describing: urlString))")
        }
        return url
    }

    func makeChannelLocation(channelID: String) throws -> URL {
        return try makeURL(channelID: channelID)
    }

    func createChannel(
        withPayload payload: ChannelRegistrationPayload
    ) async throws -> AirshipHTTPResponse<ChannelAPIResponse> {

        let url = try makeURL()
        let data = try encoder.encode(payload)

        AirshipLogger.debug(
            "Creating channel with: \(payload)"
        )

        let request = AirshipRequest(
            url: url,
            headers: [
                "Accept":  "application/vnd.urbanairship+json; version=3;",
                "Content-Type": "application/json"
            ],
            method: "POST",
            auth: .basic(config.appKey, config.appSecret),
            body: data
        )

        return try await session.performHTTPRequest(
            request
        ) { data, response in
            AirshipLogger.debug(
                "Channel creation finished with response: \(response)"
            )

            let status = response.statusCode
            guard status == 200 || status == 201 else {
                return nil
            }

            guard let data = data else {
                throw AirshipErrors.parseError("Missing body")
            }

            let json = try JSONSerialization.jsonObject(
                with: data,
                options: .allowFragments
            ) as? [AnyHashable: Any]

            guard let channelID = json?["channel_id"] as? String else {
                throw AirshipErrors.parseError("Missing channel_id")
            }

            return ChannelAPIResponse(
                channelID: channelID,
                location: try self.makeChannelLocation(channelID: channelID)
            )
        }
    }

    func updateChannel(
        channelID: String,
        withPayload payload: ChannelRegistrationPayload
    ) async throws -> AirshipHTTPResponse<ChannelAPIResponse> {

        let url = try makeURL(channelID: channelID)
        let data = try encoder.encode(payload)

        AirshipLogger.debug(
            "Updating channel \(channelID) with: \(payload)"
        )

        let request = AirshipRequest(
            url: url,
            headers: [
                "Accept": "application/vnd.urbanairship+json; version=3;",
                "Content-Type": "application/json"
            ],
            method: "PUT",
            auth: .basic(config.appKey, config.appSecret),
            body: data
        )

        return try await session.performHTTPRequest(request) { data, response in
            return ChannelAPIResponse(
                channelID: channelID,
                location: url
            )
        }
    }
}

/// - Note: For internal use only. :nodoc:
protocol ChannelAPIClientProtocol {
    func makeChannelLocation(channelID: String) throws -> URL

    func createChannel(
        withPayload payload: ChannelRegistrationPayload
    ) async throws -> AirshipHTTPResponse<ChannelAPIResponse>

    func updateChannel(
        channelID: String,
        withPayload payload: ChannelRegistrationPayload
    ) async throws -> AirshipHTTPResponse<ChannelAPIResponse>
}

struct ChannelAPIResponse {
    let channelID: String
    let location: URL
}
