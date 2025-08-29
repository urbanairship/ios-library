/* Copyright Airship and Contributors */

import Foundation
#if canImport(AirshipCore)
import AirshipCore
#endif

protocol AdditionalAudienceCheckerResolverProtocol: Actor {
    func resolve(
        deviceInfoProvider: any AudienceDeviceInfoProvider,
        additionalAudienceCheckOverrides: AdditionalAudienceCheckOverrides?
    ) async throws -> Bool
}

actor AdditionalAudienceCheckerResolver: AdditionalAudienceCheckerResolverProtocol {
    private let cache: any AirshipCache
    private let apiClient: any AdditionalAudienceCheckerAPIClientProtocol

    private let date: any AirshipDateProtocol
    private var inProgress: Task<Bool, any Error>?
    private let configProvider: () -> RemoteConfig.AdditionalAudienceCheckConfig?

    private var additionalAudienceConfig: RemoteConfig.AdditionalAudienceCheckConfig? {
        get {
            configProvider()
        }
    }

    init(
        config: RuntimeConfig,
        cache: any AirshipCache,
        date: any AirshipDateProtocol = AirshipDate.shared
    ) {
        self.cache = cache
        self.apiClient = AdditionalAudienceCheckerAPIClient(config: config)
        self.date = date
        self.configProvider = {
            config.remoteConfig.iaaConfig?.additionalAudienceConfig
        }
    }
    
    /// Testing
    init(
        cache: any AirshipCache,
        apiClient: any AdditionalAudienceCheckerAPIClientProtocol,
        date: any AirshipDateProtocol,
        configProvider: @escaping () -> RemoteConfig.AdditionalAudienceCheckConfig?
    ) {
        self.cache = cache
        self.apiClient = apiClient
        self.date = date
        self.configProvider = configProvider
    }
    
    func resolve(
        deviceInfoProvider: any AudienceDeviceInfoProvider,
        additionalAudienceCheckOverrides: AdditionalAudienceCheckOverrides?
    ) async throws -> Bool {
        
        guard
            let config = additionalAudienceConfig,
            config.isEnabled
        else {
            return true
        }

        guard
            let urlString = additionalAudienceCheckOverrides?.url ?? config.url,
            let url = URL(string: urlString)
        else {
            AirshipLogger.warn("Failed to parse additional audience check url " +
                               String(describing: additionalAudienceCheckOverrides) + ", " +
                               String(describing: config) + ")")
            throw AirshipErrors.error("Missing additional audience check url")
        }
        
        guard additionalAudienceCheckOverrides?.bypass != true else {
            AirshipLogger.trace("Additional audience check is bypassed")
            return true
        }
        let context = additionalAudienceCheckOverrides?.context ?? config.context

        _ = try? await inProgress?.value
        let task = Task {
            return try await doResolve(
                url: url,
                context: context,
                deviceInfoProvider: deviceInfoProvider
            )
        }

        inProgress = task
        return try await task.value
    }

    private func doResolve(
        url: URL,
        context: AirshipJSON?,
        deviceInfoProvider: any AudienceDeviceInfoProvider
    ) async throws -> Bool {

        let channelID = try await deviceInfoProvider.channelID
        let contactInfo = await deviceInfoProvider.stableContactInfo

        let cacheKey = try cacheKey(
            url: url.absoluteString,
            context: context ?? .null,
            contactID: contactInfo.contactID,
            channelID: channelID
        )

        if let cached: AdditionalAudienceCheckResult = await cache.getCachedValue(key: cacheKey) {
            return cached.isMatched
        }

        let request = AdditionalAudienceCheckResult.Request(
            url: url,
            channelID: channelID,
            contactID: contactInfo.contactID,
            namedUserID: contactInfo.namedUserID,
            context: context
        )

        let response = try await apiClient.resolve(info: request)

        if response.isSuccess, let result = response.result {
            await cache.setCachedValue(result, key: cacheKey, ttl: result.cacheTTL)
            return result.isMatched
        } else if response.isServerError {
            throw AirshipErrors.error("Failed to perform additional check due to server error \(response)")
        } else {
            return false
        }
    }

    private func cacheKey(url: String, context: AirshipJSON, contactID: String, channelID: String) throws -> String {
        return String([url, try context.toString(), contactID, channelID].joined(separator: ":"))
    }
}
