/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// High level interface for retrieving and caching auth tokens.
class AuthTokenManager {
    
    private var client: AuthTokenAPIClientProtocol
    private var channel: ChannelProtocol
    private var date: AirshipDate
    private var _cachedToken: AuthToken?
    
    private var cachedToken: AuthToken? {
        get {
            guard let cachedToken = _cachedToken else {
                return nil
            }
            
            if date.now.compare(cachedToken.expiration) == .orderedDescending {
                _cachedToken = nil
                return nil
            }
            
            if channel.identifier != cachedToken.channelID {
                _cachedToken = nil
                return nil
            }
            
            return cachedToken
        }
        set {
            _cachedToken = newValue
        }
    }
    
    /// AuthTokenManager class factory method. Used for testing.
    ///
    /// - Parameters:
    ///   - client: The API client.
    ///   - channel: The channel.
    ///   - date: The UADate.
    init(
        apiClient client: AuthTokenAPIClientProtocol,
        channel: ChannelProtocol,
        date: AirshipDate
    ) {
        self.client = client
        self.channel = channel
        self.date = date
    }
    
    /// AuthTokenManager class factory method. Used for testing.
    ///
    /// - Parameters:
    ///   - client: The API client.
    ///   - channel: The channel.
    convenience init(
        apiClient client: AuthTokenAPIClientProtocol,
        channel: ChannelProtocol
    ) {
        self.init(
            apiClient: client,
            channel: channel,
            date: AirshipDate())
    }
    
    /// AuthTokenManager class factory method.
    ///
    /// - Parameters:
    ///   - config: The runtime config.
    ///   - channel: The channel.
    convenience init(
        runtimeConfig config: RuntimeConfig,
        channel: ChannelProtocol
    ) {
        self.init(
            apiClient: AuthTokenAPIClient(config: config),
            channel: channel,
            date: AirshipDate())
    }
    
    /// Retrieves the current auth token, or nil if one could not be retrieved.
    func token() async -> String? {
        
        guard let identifier = channel.identifier else {
            AirshipLogger.debug("Auth token retrieval because channel identifier is nil")
            return nil
        }
        
        if let cachedToken = self.cachedToken {
            return cachedToken.token
        }
        
        var responseToken: AuthToken? = nil
        
        do {
            let response = try await client.token(withChannelID: identifier)
            if response.isSuccess {
                responseToken = response.result
            } else {
                AirshipLogger.debug("Auth token retrieval failed with status: \(response.statusCode)")
            }
        } catch {
            AirshipLogger.debug("Unable to retrieve auth token: \(error)")
        }
        
        guard let responseToken = responseToken else {
            return nil
        }
        
        self.cachedToken = responseToken
        return responseToken.token
    }
    
    /// Manually expires the provided token.
    func expireToken(
        _ token: String
    ) {
        if token == self.cachedToken?.token {
            self.cachedToken = nil
        }
    }
    
}
