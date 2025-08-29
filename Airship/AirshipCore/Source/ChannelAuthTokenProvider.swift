/* Copyright Airship and Contributors */

import Foundation

final class ChannelAuthTokenProvider: AuthTokenProvider {
    private let cachedAuthToken: CachedValue<AuthToken>

    private let channel: any AirshipChannelProtocol
    private let apiClient: any ChannelAuthTokenAPIClientProtocol
    private let date: any AirshipDateProtocol

    init(
        channel: any AirshipChannelProtocol,
        apiClient: any ChannelAuthTokenAPIClientProtocol,
        date: any AirshipDateProtocol = AirshipDate.shared
    ) {
        self.channel = channel
        self.apiClient = apiClient
        self.cachedAuthToken = CachedValue(date: date)
        self.date = date
    }

    convenience init(
        channel: any AirshipChannelProtocol,
        runtimeConfig: RuntimeConfig
    ) {
        self.init(channel: channel, apiClient: ChannelAuthTokenAPIClient(config: runtimeConfig))
    }

    func resolveAuth(identifier: String) async throws -> String {
        guard self.channel.identifier == identifier else {
            throw AirshipErrors.error("Unable to generate auth for stale channel \(identifier)")
        }

        if let token = self.cachedAuthToken.value,
           token.identifier == identifier,
           self.cachedAuthToken.timeRemaining >= 30
        {
            return token.token
        }

        let response = try await self.apiClient.fetchToken(channelID: identifier)

        guard response.isSuccess, let result = response.result else {
            throw AirshipErrors.error("Failed to fetch auth token for channel \(identifier)")
        }

        let token = AuthToken(
            identifier: identifier,
            token: result.token,
            expiration: self.date.now.advanced(by: 
                Double(result.expiresInMillseconds/1000)
            )
        )

        self.cachedAuthToken.set(value: token, expiration: token.expiration)
        return result.token
    }

    func authTokenExpired(token: String) async {
        self.cachedAuthToken.expireIf { auth in
            return auth.token == token
        }
    }
}
