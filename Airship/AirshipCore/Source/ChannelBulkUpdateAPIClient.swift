/* Copyright Airship and Contributors */

// NOTE: For internal use only. :nodoc:
protocol ChannelBulkUpdateAPIClientProtocol {
    @discardableResult
    func update(channelID: String,
                subscriptionListUpdates: [SubscriptionListUpdate]?,
                tagGroupUpdates: [TagGroupUpdate]?,
                attributeUpdates: [AttributeUpdate]?,
                completionHandler: @escaping (HTTPResponse?, Error?) -> Void) -> Disposable;
}

// NOTE: For internal use only. :nodoc:
class ChannelBulkUpdateAPIClient : ChannelBulkUpdateAPIClientProtocol {
    private static let path = "/api/channels/sdk/batch/"

    private var config: RuntimeConfig
    private var session: RequestSession

    init(config: RuntimeConfig, session: RequestSession) {
        self.config = config
        self.session = session
    }
    
    convenience init(config: RuntimeConfig) {
        self.init(config: config, session: RequestSession(config: config))
    }

    @discardableResult
    func update(channelID: String, subscriptionListUpdates: [SubscriptionListUpdate]?,
                tagGroupUpdates: [TagGroupUpdate]?,
                attributeUpdates: [AttributeUpdate]?,
                completionHandler: @escaping (HTTPResponse?, Error?) -> Void) -> Disposable {
        
        let url = buildURL(channelID: channelID)
        let payload = buildPayload(subscriptionListUpdates: subscriptionListUpdates, tagGroupUpdates: tagGroupUpdates, attributeUpdates: attributeUpdates)
        
        AirshipLogger.debug("Updating channel with url \(url?.absoluteString ?? "") payload \(payload)")

        let request = Request(builderBlock: { [self] builder in
            builder.method = "PUT"
            builder.url = url
            builder.username = config.appKey
            builder.password = config.appSecret
            builder.setValue("application/vnd.urbanairship+json; version=3;", header: "Accept")
            builder.setValue("application/json", header: "Content-Type")
            builder.body = try? JSONUtils.data(payload, options: [])
        })
        
        return session.performHTTPRequest(request, completionHandler: { (data, response, error) in
            guard let response = response else {
                AirshipLogger.debug("Update finished with error: \(error.debugDescription)")
                completionHandler(nil, error)
                return
            }

            AirshipLogger.debug("Update finished with response: \(response)")
            completionHandler(HTTPResponse(status: response.statusCode), nil)
        })
    }
    
    func buildPayload(subscriptionListUpdates: [SubscriptionListUpdate]?,
                      tagGroupUpdates: [TagGroupUpdate]?,
                      attributeUpdates: [AttributeUpdate]?) -> [AnyHashable : Any] {
    
        var payload: [AnyHashable : Any] = [:]
        
        let tags = map(tagGroupUpdates)
        if (!tags.isEmpty) {
            payload["tags"] = tags
        }
        
        let attributes = map(attributeUpdates)
        if (!attributes.isEmpty) {
            payload["attributes"] = attributes
        }
        
        let subscriptions = map(subscriptionListUpdates)
        if (!subscriptions.isEmpty) {
            payload["subscription_lists"] = subscriptions
        }
        
        return payload
    }
    
    func buildURL(channelID: String) -> URL? {
        guard let deviceUrl = config.deviceAPIURL else {
            return nil
        }
        
        var urlComps = URLComponents(string: "\(deviceUrl)\(ChannelBulkUpdateAPIClient.path)\(channelID)")
        urlComps?.queryItems = [URLQueryItem(name: "platform", value: "ios")]
        return urlComps?.url
    }
    
    
    private func map(_ attributeUpdates: [AttributeUpdate]?) -> [[AnyHashable : Any]] {
        guard let attributeUpdates = attributeUpdates else {
            return []
        }
        
        return AudienceUtils.collapse(attributeUpdates).map { (attribute) -> ([AnyHashable : Any]) in
            var action : String
            switch(attribute.type) {
            case .set:
                action = "set"
            case .remove:
                action = "remove"
            }
            
            var payload: [AnyHashable : Any] = [
                "action": action,
                "key": attribute.attribute,
                "timestamp": Utils.isoDateFormatterUTCWithDelimiter().string(from: attribute.date)
            ]
            
            if let value = attribute.value() {
                payload["value"] = value
            }
            
            return payload
        }
    }
    
    private func map(_ tagGroupUpdates: [TagGroupUpdate]?) -> [AnyHashable : Any]{
        guard let tagGroupUpdates = tagGroupUpdates else {
            return [:]
        }
        
        var tagsPayload : [String : [String: [String]]] = [:]
        
        AudienceUtils.collapse(tagGroupUpdates).forEach { tagUpdate in
            var key : String
            switch (tagUpdate.type) {
            case .add:
                key = "add"
            case .remove:
                key = "remove"
            case .set:
                key = "set"
            }
            
            if (tagsPayload[key] == nil) {
                tagsPayload[key] = [:]
            }
            tagsPayload[key]?[tagUpdate.group] = tagUpdate.tags
        }
        
        return tagsPayload
    }

    private func map(_ subscriptionListsUpdates: [SubscriptionListUpdate]?) -> [[AnyHashable : Any]] {
        guard let subscriptionListsUpdates = subscriptionListsUpdates else {
            return []
        }
        
        return AudienceUtils.collapse(subscriptionListsUpdates).map { (list) -> ([AnyHashable : Any]) in
            var action : String
            switch(list.type) {
            case .subscribe:
                action = "subscribe"
            case .unsubscribe:
                action = "unsubscribe"
            }
            return [
                "action": action,
                "list_id": list.listId
            ]
        }
    }
}
