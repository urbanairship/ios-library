/* Copyright Airship and Contributors */


#if canImport(AirshipCore)
import AirshipCore
#endif

protocol AdditionalAudienceCheckerAPIClientProtocol: Sendable {
    func resolve(
        info: AdditionalAudienceCheckResult.Request
    ) async throws -> AirshipHTTPResponse<AdditionalAudienceCheckResult>
}

struct AdditionalAudienceCheckResult: Codable, Sendable, Equatable {
    let isMatched: Bool
    let cacheTTL: TimeInterval
    
    enum CodingKeys: String, CodingKey {
        case isMatched = "allowed"
        case cacheTTL = "cache_seconds"
    }
    
    struct Request: Sendable {
        let url: URL
        let channelID: String
        let contactID: String
        let namedUserID: String?
        let context: AirshipJSON?
    }
}

final class AdditionalAudienceCheckerAPIClient: AdditionalAudienceCheckerAPIClientProtocol {
    private let config: RuntimeConfig
    private let session: any AirshipRequestSession
    private let encoder: JSONEncoder

    init(config: RuntimeConfig, session: any AirshipRequestSession, encoder: JSONEncoder = JSONEncoder()) {
        self.config = config
        self.session = session
        self.encoder = encoder
    }

    convenience init(config: RuntimeConfig) {
        self.init(
            config: config,
            session: config.requestSession
        )
    }
    
    func resolve(
        info: AdditionalAudienceCheckResult.Request
    ) async throws -> AirshipHTTPResponse<AdditionalAudienceCheckResult> {
        
        let body = RequestBody(
            channelID: info.channelID,
            contactID: info.contactID,
            namedUserID: info.namedUserID,
            context: info.context
        )

        let request = AirshipRequest(
            url: info.url,
            headers: [
                "Content-Type": "application/json",
                "Accept": "application/vnd.urbanairship+json; version=3;",
                "X-UA-Contact-ID": info.contactID,
                "X-UA-Device-Family": "ios",
            ],
            method: "POST",
            auth: .contactAuthToken(identifier: info.contactID),
            body: try encoder.encode(body)
        )
        
        AirshipLogger.trace("Performing additional audience check with request \(request), body: \(body)")
        
        return try await session.performHTTPRequest(request) { data, response in
            AirshipLogger.debug("Additional audience check response finished with response: \(response)")
            
            guard (200..<300).contains(response.statusCode) else {
                return nil
            }
            
            guard let data = data else {
                throw AirshipErrors.error("Invalid response body \(String(describing: data))")
            }
            
            return try JSONDecoder().decode(AdditionalAudienceCheckResult.self, from: data)
        }
    }
    
    fileprivate struct RequestBody: Encodable {
        let channelID: String
        let contactID: String
        let namedUserID: String?
        let context: AirshipJSON?

        enum CodingKeys: String, CodingKey {
            case channelID = "channel_id"
            case contactID = "contact_id"
            case namedUserID = "named_user_id"
            case context
        }
    }
}
