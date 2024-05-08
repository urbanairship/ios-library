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

actor TestContactChannelsProvider: ContactChannelsProviderProtocol, @unchecked Sendable {
    func contactUpdates(contactID: String) async throws -> AsyncStream<[AirshipCore.ContactChannel]> {
        return AsyncStream<[AirshipCore.ContactChannel]> { _ in }
    }

    init() {}
}


//ContactChannelsProviderProtocol
//ContactChannelsAPIClientProtocol

class TestChannelsListAPIClient: ContactChannelsAPIClientProtocol, @unchecked Sendable {

    func fetchAssociatedChannelsList(
        contactID: String
    ) async throws -> AirshipHTTPResponse<[ContactChannel]> {
        return AirshipHTTPResponse(result: nil, statusCode: 200, headers: [:])
    }

    init() {}
}
