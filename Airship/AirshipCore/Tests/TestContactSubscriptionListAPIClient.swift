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
    
    var fetchAssociatedChannelsListCallback:
        ((String, String) async throws -> AirshipHTTPResponse<[AssociatedChannel]>)?
    
    var fetchSubscriptionListsCallback:
        ((String) async throws -> AirshipHTTPResponse<[String: [ChannelScope]]>)?

    init() {}

    func fetchAssociatedChannelsList(contactID: String, type: String) async throws -> AirshipHTTPResponse<[AssociatedChannel]> {
        return try await fetchAssociatedChannelsListCallback!(contactID, type)
    }

    func checkOptinStatus() async throws -> AirshipHTTPResponse<[AirshipChannelOptinStatus]> {
        // TODO
        return AirshipHTTPResponse(
            result: [],
            statusCode: 200,
            headers: [:])
    }
}
