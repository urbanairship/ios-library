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
