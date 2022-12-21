import Foundation

@testable import AirshipCore

class TestChannelBulkUpdateAPIClient: ChannelBulkUpdateAPIClientProtocol {

    var updateCallback:
        ((String, AudienceUpdate) async throws ->  AirshipHTTPResponse<Void>)?

    init() {}

    func update(_ update: AirshipCore.AudienceUpdate, channelID: String) async throws -> AirshipCore.AirshipHTTPResponse<Void> {
        try await self.updateCallback!(channelID, update)
    }
}
