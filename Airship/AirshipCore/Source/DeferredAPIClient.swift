/* Copyright Airship and Contributors */

protocol DeferredAPIClientProtocol: Sendable {
    func resolve(
        url: URL,
        channelID: String,
        contactID: String?,
        stateOverrides: AirshipStateOverrides,
        audienceOverrides: ChannelAudienceOverrides,
        triggerContext: AirshipTriggerContext?
    ) async throws -> AirshipHTTPResponse<Data>
}

final class DeferredAPIClient: DeferredAPIClientProtocol {

    func resolve(
        url: URL,
        channelID: String,
        contactID: String?,
        stateOverrides: AirshipStateOverrides,
        audienceOverrides: ChannelAudienceOverrides,
        triggerContext: AirshipTriggerContext?
    ) async throws -> AirshipHTTPResponse<Data> {
        var tagOverrides: TagGroupOverrides?
        if (!audienceOverrides.tags.isEmpty) {
            tagOverrides = TagGroupOverrides.from(updates: audienceOverrides.tags)
        }

        var attributeOverrides: [AttributeOperation]?
        if (!audienceOverrides.attributes.isEmpty) {
            attributeOverrides = audienceOverrides.attributes.map { $0.operation }
        }

        let body = RequestBody(
            channelID: channelID,
            contactID: contactID,
            stateOverrides: stateOverrides,
            triggerContext: triggerContext,
            tagOverrides: tagOverrides,
            attributeOverrides: attributeOverrides
        )

        let request = AirshipRequest(
            url: url,
            headers: [
                "Accept": "application/vnd.urbanairship+json; version=3;"
            ],
            method: "POST",
            auth: .channelAuthToken(identifier: channelID),
            body: try JSONEncoder().encode(body)
        )

        AirshipLogger.trace("Resolving deferred with request \(request) body \(body)")

        return try await session.performHTTPRequest(request) { data, response in
            
            AirshipLogger.debug("Resolving deferred response finished with response: \(response)")

            if (response.statusCode == 200) {
                return data
            }

            return nil
        }
    }


    private let config: RuntimeConfig
    private let session: any AirshipRequestSession

    init(config: RuntimeConfig, session: any AirshipRequestSession) {
        self.config = config
        self.session = session
    }

    convenience init(config: RuntimeConfig) {
        self.init(
            config: config,
            session: config.requestSession
        )
    }

    fileprivate struct RequestBody: Encodable {
        let platform: String = "ios"
        let channelID: String
        let contactID: String?
        let stateOverrides: AirshipStateOverrides
        let triggerContext: AirshipTriggerContext?
        let tagOverrides: TagGroupOverrides?
        let attributeOverrides: [AttributeOperation]?


        enum CodingKeys: String, CodingKey {
            case platform
            case channelID = "channel_id"
            case contactID = "contact_id"
            case stateOverrides = "state_overrides"
            case triggerContext = "trigger"
            case tagOverrides = "tag_overrides"
            case attributeOverrides = "attribute_overrides"
        }
    }
}

