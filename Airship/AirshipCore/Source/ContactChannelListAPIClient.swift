/* Copyright Airship and Contributors */

import Foundation

// NOTE: For internal use only. :nodoc:
public protocol ChannelsListAPIClientProtocol: Sendable {
    func fetchChannelsList(
        contactID: String
    ) async throws -> AirshipHTTPResponse<[AssociatedChannelType]>
    
    func checkOptinStatus() async throws -> AirshipHTTPResponse<[AirshipChannelOptinStatus]>
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
    ) async throws -> AirshipHTTPResponse<[AssociatedChannelType]> {
        AirshipLogger.debug("Retrieving channels list")
        
        // TODO: Fix API call
        return AirshipHTTPResponse(
            result: [
                .sms(
                    SMSAssociatedChannel(
                        channelID: "00000000-0000-0000-0001",
                        msisdn: "*******7734",
                        optIn: true
                    )
                ),
                .email(
                    EmailAssociatedChannel(
                        channelID: "00000000-0000-0000-0002",
                        address: "t*****@example.com",
                        commercialOptedIn: Date(),
                        commercialOptedOut: nil,
                        transactionalOptedIn: Date()
                    )
                )
            ],
            statusCode: 200,
            headers: [:]
        )
    }
    
    func checkOptinStatus() throws -> AirshipHTTPResponse<[AirshipChannelOptinStatus]> {
        // TODO: Fix API call
        return AirshipHTTPResponse(
            result: [
                AirshipChannelOptinStatus(
                    type: .email,
                    id: "j****@gmail.com",
                    sender: nil,
                    status: .optIn
                ),
                AirshipChannelOptinStatus(
                    type: .sms,
                    id: "617-960-****",
                    sender: "12345",
                    status: .optIn
                )
            ],
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
