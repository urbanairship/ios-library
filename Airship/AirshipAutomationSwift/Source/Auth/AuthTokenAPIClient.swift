/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

protocol AuthTokenAPIClientProtocol {
    ///
    /// Retrieves the token associated with the provided channel ID.
    /// - Parameters:
    ///   - channelID: The channel ID.
    /// - Returns: AuthToken if succeed otherwise it throws an error
    func token(
        withChannelID channelID: String
    ) async throws -> AirshipHTTPResponse<AuthToken>
}

class AuthTokenAPIClient: AuthTokenAPIClientProtocol {
    
    var config: RuntimeConfig
    var session: AirshipRequestSession
    
    init(
        config: RuntimeConfig,
        session: AirshipRequestSession
    ) {
        self.config = config
        self.session = session
    }
    
    convenience init(
        config: RuntimeConfig
    ) {
        self.init(
            config: config,
            session: AirshipRequestSession(appKey: config.appKey))
    }
    
    func token(
        withChannelID channelID: String
    ) async throws -> AirshipHTTPResponse<AuthToken> {
        
        guard let deviceAPIURL = self.config.deviceAPIURL else {
            throw AirshipErrors.error("App config not available.")
        }
        
        let urlString = "\(deviceAPIURL)/api/auth/device"
        let request = AirshipRequest(
            url: URL(string: urlString),
            headers: [
                "Accept": "application/vnd.urbanairship+json; version=3;",
                "X-UA-Channel-ID": channelID,
                "X-UA-App-Key": self.config.appKey
            ],
            method: "GET",
            auth: .bearer(config.appSecret, config.appKey, channelID)
        )
        
        return try await session.performHTTPRequest(
            request
        ) { data, response in
            
            // Unsuccessful HTTP response
            guard response.isSuccess else {
                return nil
            }
            
            // Successful HTTP response
            AirshipLogger.trace("Auth token request succeeded with status: \(response.statusCode)");
            
            let responseBody: AuthTokenResponse = try JSONUtils.decode(data: data)
            
            let expirationDate = Date(timeIntervalSince1970: TimeInterval(responseBody.expiration))
            
            return AuthToken(
                channelID: channelID,
                token: responseBody.token,
                expiration: expirationDate)
        }
    }
}

class AuthTokenResponse: Decodable {
    var token: String
    var expiration: Int
    
    enum CodingKeys: String, CodingKey {
        case token = "token"
        case expiration = "expires_in"
    }
}

extension HTTPURLResponse {
    fileprivate var isSuccess: Bool {
        return self.statusCode >= 200 && self.statusCode <= 299
    }
}
