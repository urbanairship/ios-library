/* Copyright Airship and Contributors */

/// - Note: For internal use only. :nodoc:
final class ChannelAPIClient: ChannelAPIClientProtocol, Sendable {
    private let channelPath = "/api/channels/"

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

    func makeChannelLocation(channelID: String) throws -> URL {
        return try makeURL(path: "\(self.channelPath)\(channelID)")
    }


    func createChannel(
        payload: ChannelRegistrationPayload
    ) async throws -> AirshipHTTPResponse<ChannelAPIResponse> {
        let url = try makeURL(path: self.channelPath)
        let data = try JSONEncoder().encode(payload)

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
            auth: .generatedAppToken,
            body: data
        )

        return try await session.performHTTPRequest(
            request
        ) { data, response in
            
            AirshipLogger.debug("Channel creation finished with response: \(response)")

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
        _ channelID: String,
        payload: ChannelRegistrationPayload
    ) async throws -> AirshipHTTPResponse<ChannelAPIResponse> {

        let url = try makeChannelLocation(channelID: channelID)
        let data = try JSONEncoder().encode(payload)

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
            auth: .channelAuthToken(identifier: channelID),
            body: data
        )

        return try await session.performHTTPRequest(request) { data, response in
            
            AirshipLogger.debug("Update channel finished with response: \(response)")
            
            return ChannelAPIResponse(
                channelID: channelID,
                location: url
            )
        }
    }
    
    var isURLConfigured: Bool {
        return self.config.deviceAPIURL?.isEmpty == false
    }

}

/// - Note: For internal use only. :nodoc:
protocol ChannelAPIClientProtocol {
    func makeChannelLocation(channelID: String) throws -> URL

    func createChannel(
        payload: ChannelRegistrationPayload
    ) async throws -> AirshipHTTPResponse<ChannelAPIResponse>

    func updateChannel(
        _ channelID: String,
        payload: ChannelRegistrationPayload
    ) async throws -> AirshipHTTPResponse<ChannelAPIResponse>

    var isURLConfigured: Bool { get }
}

struct ChannelAPIResponse {
    let channelID: String
    let location: URL
}


