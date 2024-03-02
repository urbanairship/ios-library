/* Copyright Airship and Contributors */

import Foundation

// NOTE: For internal use only. :nodoc:
public protocol ChannelsListAPIClientProtocol: Sendable {
    func fetchChannelsList(
        contactID: String
    ) async throws -> AirshipHTTPResponse<[AssociatedChannel]>
}

// NOTE: For internal use only. :nodoc:
final class ChannelsListAPIClient: ChannelsListAPIClientProtocol {
    private let config: RuntimeConfig
    private let session: AirshipRequestSession
    
    init(config: RuntimeConfig, session: AirshipRequestSession) {
        self.config = config
        self.session = session
    }
    
    convenience init(config: RuntimeConfig) {
        self.init(config: config, session: config.requestSession)
    }
    
    func fetchChannelsList(
        contactID: String
    ) async throws -> AirshipHTTPResponse<[AssociatedChannel]> {
        AirshipLogger.debug("Retrieving channels list")
        
        // TODO: Fix API call
        return AirshipHTTPResponse(
            result: [],
            statusCode: 200,
            headers: [:]
        )
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

struct ChannelResponseBody: Decodable {
    let channelLists: [AssociatedChannel]
    
    enum CodingKeys: String, CodingKey {
        case channelLists = "channels_list"
    }
}
