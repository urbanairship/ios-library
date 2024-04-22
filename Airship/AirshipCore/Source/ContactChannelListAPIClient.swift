/* Copyright Airship and Contributors */

import Foundation

// NOTE: For internal use only. :nodoc:
public protocol ChannelsListAPIClientProtocol: Sendable {
    func fetchAssociatedChannelsList(
        contactID: String,
        type: String
    ) async throws -> AirshipHTTPResponse<[AssociatedChannel]>
    
    func checkOptinStatus() async throws -> AirshipHTTPResponse<[AirshipChannelOptinStatus]>
}

// NOTE: For internal use only. :nodoc:
final class ChannelsListAPIClient: ChannelsListAPIClientProtocol {
    private let config: RuntimeConfig
    private let session: AirshipRequestSession
    
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom({ (decoder) -> Date in
            let container = try decoder.singleValueContainer()
            let dateStr = try container.decode(String.self)

            guard let date = AirshipDateFormatter.date(fromISOString: dateStr) else {
                throw AirshipErrors.error("Invalid date \(dateStr)")
            }
            return date
        })
        return decoder
    }()
    
    init(config: RuntimeConfig, session: AirshipRequestSession) {
        self.config = config
        self.session = session
    }
    
    convenience init(config: RuntimeConfig) {
        self.init(config: config, session: config.requestSession)
    }
    
    func fetchAssociatedChannelsList(
        contactID: String,
        type: String
    ) async throws -> AirshipHTTPResponse<[AssociatedChannel]> {
        AirshipLogger.debug("Retrieving associated channels list")
        
        let request = AirshipRequest(
            url: try self.makeURL(path: "/api/contacts/associated_types/\(contactID)?channel_type=\(type)"),
            headers: [
                "Accept": "application/vnd.urbanairship+json; version=3;",
                "Content-Type": "application/json"
            ],
            method: "GET",
            auth: .contactAuthToken(identifier: contactID)
        )

        return try await self.session.performHTTPRequest(
            request
        ) { (data, response) in
            
            AirshipLogger.debug("Fetching associated channels list finished with response: \(response)")

            guard response.statusCode == 200, let data = data else {
                return nil
            }

            let result = try self.decoder.decode(
                AssociatedChannelsResponseBody.self,
                from: data
            )
            
            return result.associated_types
        }
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

struct AssociatedChannelsResponseBody: Codable {
    let associated_types: [AssociatedChannel]
    
    enum CodingKeys: String, CodingKey {
        case associated_types = "associated_types"
    }
}
