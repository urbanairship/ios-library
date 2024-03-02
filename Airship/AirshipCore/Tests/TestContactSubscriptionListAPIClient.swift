import Foundation

@testable import AirshipCore

class TestContactSubscriptionListAPIClient: ContactSubscriptionListAPIClientProtocol, @unchecked Sendable {
    var fetchSubscriptionListsCallback:
        ((String) async throws -> AirshipHTTPResponse<[String: [ChannelScope]]>)?

    init() {}

    func fetchSubscriptionLists(
        contactID: String
    ) async throws -> AirshipHTTPResponse<[String: [ChannelScope]]> {
        return try await fetchSubscriptionListsCallback!(contactID)
    }

}


class TestChannelsListAPIClient: ChannelsListAPIClientProtocol {
    
    var fetchChannelsListCallback:
        ((String) async throws -> AirshipHTTPResponse<[AssociatedChannel]>)?
    
    var fetchSubscriptionListsCallback:
        ((String) async throws -> AirshipHTTPResponse<[String: [ChannelScope]]>)?

    init() {}

    func fetchChannelsList(contactID: String) async throws -> AirshipHTTPResponse<[AssociatedChannel]> {
        return try await fetchChannelsListCallback!(contactID)
    }

}
