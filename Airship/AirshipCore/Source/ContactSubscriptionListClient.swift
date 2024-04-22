/* Copyright Airship and Contributors */

import Foundation

/// NOTE: For internal use only. :nodoc:
protocol ContactSubscriptionListAPIClientProtocol: Sendable {
    func fetchSubscriptionLists(
        contactID: String
    ) async throws ->  AirshipHTTPResponse<[String: [ChannelScope]]>
}

/// NOTE: For internal use only. :nodoc:
final class ContactSubscriptionListAPIClient: ContactSubscriptionListAPIClientProtocol {
    private let config: RuntimeConfig
    private let session: AirshipRequestSession

    init(config: RuntimeConfig, session: AirshipRequestSession) {
        self.config = config
        self.session = session
    }

    convenience init(config: RuntimeConfig) {
        self.init(config: config, session: config.requestSession)
    }

    func fetchSubscriptionLists(
        contactID: String
    ) async throws -> AirshipHTTPResponse<[String: [ChannelScope]]> {
        AirshipLogger.debug("Retrieving subscription lists associated with a contact")

        let request = AirshipRequest(
            url: try self.makeURL(path: "/api/subscription_lists/contacts/\(contactID)"),
            headers: [
                "Accept":  "application/vnd.urbanairship+json; version=3;",
                "X-UA-Appkey": self.config.appKey,
            ],
            method: "GET",
            auth: .contactAuthToken(identifier: contactID)
        )

        return try await session.performHTTPRequest(request) { data, response in
            
            AirshipLogger.debug("Fetch subscription lists finished with response: \(response)")
            
            guard response.statusCode == 200, let data = data else {
                return nil
            }

            let parsedBody = try JSONDecoder().decode(
                SubscriptionResponseBody.self,
                from: data
            )

            return try parsedBody.toScopedSubscriptionLists()
        }
    }

    private func makeURL(path: String) throws -> URL {
        guard let deviceAPIURL = self.config.deviceAPIURL else {
            throw AirshipErrors.error("Initial config not resolved.")
        }

        let urlString = "\(deviceAPIURL)\(path)"

        guard let url = URL(string: "\(deviceAPIURL)\(path)") else {
            throw AirshipErrors.error("Invalid ContactAPIClient URL: \(String(describing: urlString))")
        }

        return url
    }
}

struct SubscriptionResponseBody: Decodable {
    let subscriptionLists: [Entry]

    enum CodingKeys: String, CodingKey {
        case subscriptionLists = "subscription_lists"
    }

    struct Entry: Decodable, Equatable {
        let lists: [String]
        let scope: String

        enum CodingKeys: String, CodingKey {
            case lists = "list_ids"
            case scope = "scope"
        }
    }

    func toScopedSubscriptionLists() throws -> [String: [ChannelScope]] {
        var parsed: [String: [ChannelScope]] = [:]
        try self.subscriptionLists.forEach { entry in
            let scope = try ChannelScope.fromString(entry.scope)
            entry.lists.forEach { listID in
                var scopes = parsed[listID] ?? []
                if !scopes.contains(scope) {
                    scopes.append(scope)
                    parsed[listID] = scopes
                }
            }
        }
        return parsed
    }
}
