import Foundation

@testable import AirshipCore

public class TestSubscriptionListAPIClient: SubscriptionListAPIClientProtocol {
    var getCallback:
        ((String) async throws -> AirshipHTTPResponse<[String]>)?

    init() {}

    public func get(
        channelID: String
    ) async throws -> AirshipHTTPResponse<[String]> {
        return try await getCallback!(channelID)

    }
}
