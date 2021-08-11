/* Copyright Airship and Contributors */

// NOTE: For internal use only. :nodoc:
protocol SubscriptionListAPIClientProtocol {
    @discardableResult
    func get(channelID: String, completionHandler: @escaping (SubscriptionListFetchResponse?, Error?) -> Void) -> UADisposable;
}

// NOTE: For internal use only. :nodoc:
class SubscriptionListAPIClient : SubscriptionListAPIClientProtocol {

    private static let getPath = "/api/subscription_lists/channels/"
    
    private var config: UARuntimeConfig
    private var session: UARequestSession

    init(config: UARuntimeConfig, session: UARequestSession) {
        self.config = config
        self.session = session
    }
    
    convenience init(config: UARuntimeConfig) {
        self.init(config: config, session: UARequestSession(config: config))
    }

    
    @discardableResult
    func get(channelID: String, completionHandler: @escaping (SubscriptionListFetchResponse?, Error?) -> Void) -> UADisposable {

        AirshipLogger.debug("Retrieving subscription lists")

        let request = UARequest(builderBlock: { [self] builder in
            builder.method = "GET"
            builder.url = URL(string: "\(config.deviceAPIURL ?? "")\(SubscriptionListAPIClient.getPath)\(channelID)")
            builder.username = config.appKey
            builder.password = config.appSecret
            builder.setValue("application/vnd.urbanairship+json; version=3;", header: "Accept")
        })

        return session.performHTTPRequest(request, completionHandler: { (data, response, error) in
            guard let response = response else {
                AirshipLogger.debug("Retrieving subscription lists finished with error: \(error.debugDescription)")
                completionHandler(nil, error)
                return
            }

            if (response.statusCode == 200) {
                AirshipLogger.debug("Retrieved lists with response: \(response)")

                do {
                    guard data != nil else {
                        completionHandler(nil, AirshipErrors.parseError("Missing body"))
                        return
                    }

                    guard let jsonResponse = try JSONSerialization.jsonObject(with: data!, options: .allowFragments) as? [AnyHashable : Any] else {
                        completionHandler(nil, AirshipErrors.parseError("Invalid response."))
                        return
                    }
                    
                    guard let listIDs = jsonResponse["list_ids"] as? [String] else {
                        completionHandler(nil, AirshipErrors.parseError("Invalid response \(jsonResponse)"))
                        return
                    }

                    let subscriptionDataResponse = SubscriptionListFetchResponse(status: response.statusCode, listIDs:listIDs)
                    completionHandler(subscriptionDataResponse, nil)
                } catch {
                    completionHandler(nil, error)
                }
            } else {
                completionHandler(SubscriptionListFetchResponse(status: response.statusCode), nil)
            }
        })
    }

    private func map(subscriptionListsUpdates: [SubscriptionListUpdate]) -> [[AnyHashable : Any]] {
        return subscriptionListsUpdates.map { (list) -> ([AnyHashable : Any]) in
            switch(list.type) {
            case .subscribe:
                return [
                    "action": "subscribe",
                    "list_id": list.listId
                ]
            case .unsubscribe:
                return [
                    "action": "unsubscribe",
                    "list_id": list.listId
                ]
            }
        }
    }
}
