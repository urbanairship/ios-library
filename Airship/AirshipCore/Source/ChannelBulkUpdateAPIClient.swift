/* Copyright Airship and Contributors */

import Foundation

/// NOTE: For internal use only. :nodoc:
protocol ChannelBulkUpdateAPIClientProtocol: Sendable {
    func update(
        _ update: AudienceUpdate,
        channelID: String
    ) async throws -> AirshipHTTPResponse<Void>
}

/// NOTE: For internal use only. :nodoc:
final class ChannelBulkUpdateAPIClient: ChannelBulkUpdateAPIClientProtocol {
    private static let path: String = "/api/channels/sdk/batch/"

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

    func update(
        _ update: AudienceUpdate,
        channelID: String
    ) async throws -> AirshipHTTPResponse<Void> {
        let url = try makeURL(channelID: channelID)
        let payload = update.clientPayload

        let encoder = JSONEncoder()
        let data = try encoder.encode(payload)

        AirshipLogger.debug(
            "Updating channel with url \(url.absoluteString) payload \(String(data: data, encoding: .utf8) ?? "")"
        )

        let request = AirshipRequest(
            url: url,
            headers: [
                "Accept": "application/vnd.urbanairship+json; version=3;",
                "Content-Type": "application/json"
            ],
            method: "PUT",
            auth: .channelAuthToken(identifier: channelID),
            body: try encoder.encode(payload)
        )
        let result = try await session.performHTTPRequest(request)
        AirshipLogger.debug(
            "Updating channel finished with result \(result)"
        )
        return result
    }

    func makeURL(channelID: String) throws -> URL {
        guard let deviceUrl = config.deviceAPIURL else {
            throw AirshipErrors.error("URL config not downloaded.")
        }

        var urlComps = URLComponents(
            string: "\(deviceUrl)\(ChannelBulkUpdateAPIClient.path)\(channelID)"
        )
        urlComps?.queryItems = [URLQueryItem(name: "platform", value: "ios")]

        guard let url = urlComps?.url else {
            throw AirshipErrors.error("Invalid url from \(String(describing: urlComps)).")
        }

        return url
    }
}

extension AudienceUpdate {
    fileprivate var clientPayload: ClientPayload {
        var subscriptionLists: [SubscriptionListOperation]?
        if (!self.subscriptionListUpdates.isEmpty) {
            subscriptionLists = self.subscriptionListUpdates.map { $0.operation }
        }

        var attributes: [AttributeOperation]?
        if (!self.attributeUpdates.isEmpty) {
            attributes = self.attributeUpdates.map { $0.operation }
        }

        var tags: TagGroupOverrides?
        if (!self.tagGroupUpdates.isEmpty) {
            tags = TagGroupOverrides.from(updates: self.tagGroupUpdates)
        }

        var liveActivities: [LiveActivityUpdate]?
        if (!self.liveActivityUpdates.isEmpty) {
            liveActivities = self.liveActivityUpdates
        }


        return ClientPayload(
            tags: tags,
            subscriptionLists: subscriptionLists,
            attributes: attributes,
            liveActivities: liveActivities
        )
    }
}

private struct ClientPayload: Encodable {
    var tags: TagGroupOverrides?
    var subscriptionLists: [SubscriptionListOperation]?
    var attributes: [AttributeOperation]?
    var liveActivities: [LiveActivityUpdate]?

    enum CodingKeys: String, CodingKey {
        case tags = "tags"
        case subscriptionLists = "subscription_lists"
        case attributes = "attributes"
        case liveActivities = "live_activities"
    }
}
