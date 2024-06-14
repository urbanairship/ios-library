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
    nonisolated func contactChannels(stableContactIDUpdates: AsyncStream<String>) -> AsyncStream<ContactChannelsResult> {
        return AsyncStream<ContactChannelsResult> { _ in }
    }
    
    func contactUpdates(contactID: String) async throws -> AsyncStream<[ContactChannel]> {
        return AsyncStream<[ContactChannel]> { _ in }
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
