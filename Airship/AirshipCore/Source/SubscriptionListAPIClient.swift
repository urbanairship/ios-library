/* Copyright Airship and Contributors */
import Foundation

// NOTE: For internal use only. :nodoc:
protocol SubscriptionListAPIClientProtocol {
    func get(
        channelID: String
    ) async throws -> AirshipHTTPResponse<[String]>
}

// NOTE: For internal use only. :nodoc:
class SubscriptionListAPIClient: SubscriptionListAPIClientProtocol {

    private static let getPath = "/api/subscription_lists/channels/"

    private var config: RuntimeConfig
    private var session: AirshipRequestSession

    init(config: RuntimeConfig, session: AirshipRequestSession) {
        self.config = config
        self.session = session
    }

    convenience init(config: RuntimeConfig) {
        self.init(
            config: config,
            session: config.requestSession
        )
    }

    func get(channelID: String) async throws -> AirshipHTTPResponse<[String]> {
        AirshipLogger.debug("Retrieving subscription lists")

        guard let deviceAPIURL = config.deviceAPIURL else {
            throw AirshipErrors.error("App config not available.")
        }

        let url = URL(
            string:
                "\(deviceAPIURL)\(SubscriptionListAPIClient.getPath)\(channelID)"
        )

        let request = AirshipRequest(
            url: url,
            headers: [
                "Accept":  "application/vnd.urbanairship+json; version=3;"
            ],
            method: "GET",
            auth: .basicAppAuth
        )

        return try await session.performHTTPRequest(request) { data, response in
            guard response.statusCode == 200 else {
                return nil
            }

            guard let data = data,
                  let jsonResponse = try JSONSerialization.jsonObject(
                    with: data,
                    options: .allowFragments
                  ) as? [AnyHashable: Any]
            else {
                throw AirshipErrors.error("Invalid response body \(String(describing: data))")
            }

            return jsonResponse["list_ids"] as? [String] ?? []
        }

    }


    private func map(subscriptionListsUpdates: [SubscriptionListUpdate])
        -> [[AnyHashable: Any]]
    {
        return subscriptionListsUpdates.map { (list) -> ([AnyHashable: Any]) in
            switch list.type {
            case .subscribe:
                return [
                    "action": "subscribe",
                    "list_id": list.listId,
                ]
            case .unsubscribe:
                return [
                    "action": "unsubscribe",
                    "list_id": list.listId,
                ]
            }
        }
    }
}
