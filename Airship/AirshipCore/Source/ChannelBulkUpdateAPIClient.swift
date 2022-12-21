/* Copyright Airship and Contributors */

// NOTE: For internal use only. :nodoc:
protocol ChannelBulkUpdateAPIClientProtocol {
    func update(
        _ update: AudienceUpdate,
        channelID: String
    ) async throws -> AirshipHTTPResponse<Void>
}

// NOTE: For internal use only. :nodoc:
class ChannelBulkUpdateAPIClient: ChannelBulkUpdateAPIClientProtocol {
    private static let path = "/api/channels/sdk/batch/"

    private var config: RuntimeConfig
    private var session: AirshipRequestSession
    private var encoder: JSONEncoder = JSONEncoder()

    init(config: RuntimeConfig, session: AirshipRequestSession) {
        self.config = config
        self.session = session
    }

    convenience init(config: RuntimeConfig) {
        self.init(
            config: config,
            session: AirshipRequestSession(
                appKey: config.appKey
            )
        )
    }

    func update(
        _ update: AudienceUpdate,
        channelID: String
    ) async throws -> AirshipHTTPResponse<Void> {
        let url = try makeURL(channelID: channelID)
        let payload = update.clientPayload

        AirshipLogger.debug(
            "Updating channel with url \(url.absoluteString) payload \(payload)"
        )

        let request = AirshipRequest(
            url: url,
            headers: [
                "Accept": "application/vnd.urbanairship+json; version=3;",
                "Content-Type": "application/json"
            ],
            method: "PUT",
            auth: .basic(config.appKey, config.appSecret),
            body: try? encoder.encode(payload)
        )
        return try await session.performHTTPRequest(request)
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

    fileprivate var clientSubscriptionListPayload:
        [ClientPayload.SubscriptionOperation]?
    {
        guard !self.subscriptionListUpdates.isEmpty else { return nil }

        return self.subscriptionListUpdates.map { update in
            switch update.type {
            case .subscribe:
                return ClientPayload.SubscriptionOperation(
                    action: .subscribe,
                    listID: update.listId
                )
            case .unsubscribe:
                return ClientPayload.SubscriptionOperation(
                    action: .unsubscribe,
                    listID: update.listId
                )
            }
        }
    }

    fileprivate var clientAttributePayload: [ClientPayload.AttributeOperation]?
    {
        guard !self.attributeUpdates.isEmpty else { return nil }

        return self.attributeUpdates.map { update in
            let timestamp = Utils.isoDateFormatterUTCWithDelimiter()
                .string(
                    from: update.date
                )
            switch update.type {
            case .set:
                return ClientPayload.AttributeOperation(
                    action: .set,
                    key: update.attribute,
                    timestamp: timestamp,
                    value: try? AirshipJSON.wrap(update.value())
                )
            case .remove:
                return ClientPayload.AttributeOperation(
                    action: .remove,
                    key: update.attribute,
                    timestamp: timestamp,
                    value: nil
                )
            }
        }
    }

    fileprivate var clientLiveActivitiesPayload: [LiveActivityUpdate]? {
        guard !self.liveActivityUpdates.isEmpty else { return nil }
        return liveActivityUpdates
    }

    fileprivate var clientTagPayload: ClientPayload.TagPayload? {
        guard !self.tagGroupUpdates.isEmpty else { return nil }

        var tagPayload = ClientPayload.TagPayload()
        self.tagGroupUpdates.forEach { tagUpdate in
            switch tagUpdate.type {
            case .set:
                if tagPayload.set == nil {
                    tagPayload.set = [:]
                }
                tagPayload.set?[tagUpdate.group] = tagUpdate.tags
            case .remove:
                if tagPayload.remove == nil {
                    tagPayload.remove = [:]
                }
                tagPayload.remove?[tagUpdate.group] = tagUpdate.tags
            case .add:
                if tagPayload.add == nil {
                    tagPayload.add = [:]
                }
                tagPayload.add?[tagUpdate.group] = tagUpdate.tags
            }
        }

        return tagPayload
    }

    fileprivate var clientPayload: ClientPayload {
        return ClientPayload(
            tags: self.clientTagPayload,
            subscriptionLists: self.clientSubscriptionListPayload,
            attributes: self.clientAttributePayload,
            liveActivities: self.clientLiveActivitiesPayload
        )
    }
}

private struct ClientPayload: Encodable {

    struct TagPayload: Encodable {
        var add: [String: [String]]? = nil
        var remove: [String: [String]]? = nil
        var set: [String: [String]]? = nil
    }

    enum SubscriptionAction: String, Encodable {
        case subscribe
        case unsubscribe
    }

    struct SubscriptionOperation: Encodable {
        var action: SubscriptionAction
        var listID: String

        enum CodingKeys: String, CodingKey {
            case action = "action"
            case listID = "list_id"
        }
    }

    enum AttributeAction: String, Encodable {
        case set
        case remove
    }

    struct AttributeOperation: Encodable {
        var action: AttributeAction
        var key: String
        var timestamp: String
        var value: AirshipJSON?
    }

    let tags: TagPayload?
    let subscriptionLists: [SubscriptionOperation]?
    let attributes: [AttributeOperation]?
    let liveActivities: [LiveActivityUpdate]?

    enum CodingKeys: String, CodingKey {
        case tags = "tags"
        case subscriptionLists = "subscription_lists"
        case attributes = "attributes"
        case liveActivities = "live_activities"
    }
}
