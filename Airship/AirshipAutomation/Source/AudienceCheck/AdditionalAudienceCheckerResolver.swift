/* Copyright Airship and Contributors */

import Foundation
#if canImport(AirshipCore)
import AirshipCore
#endif

protocol AdditionalAudienceCheckerResolverProtocol: AnyActor {
    func resolve(
        deviceInfoProvider: AudienceDeviceInfoProvider,
        audienceCheckOptions: AudienceCheckOverrides?
    ) async throws -> Bool
}

actor AdditionalAudienceCheckerResolver: AdditionalAudienceCheckerResolverProtocol {
    private let cache: AirshipCache
    private let apiClient: AdditionalAudienceCheckerAPIClientProtocol
    private let additionalAudienceConfig: RemoteConfig.AdditionalAudienceCheckConfig?
    private let date: AirshipDateProtocol
    private var inProgress: Task<Bool, Error>?

    init(
        config: RuntimeConfig,
        cache: AirshipCache,
        apiClient: AdditionalAudienceCheckerAPIClientProtocol? = nil,
        date: AirshipDateProtocol = AirshipDate.shared
    ) {
        self.cache = cache
        self.apiClient = apiClient ?? AdditionalAudienceCheckerAPIClient(config: config)
        self.additionalAudienceConfig = config.remoteConfig.iaaConfig?.additionalAudienceConfig
        self.date = date
    }
    
    init(
        config: RuntimeConfig,
        cache: AirshipCache,
        audienceCheckConfig: RemoteConfig.AdditionalAudienceCheckConfig? = nil,
        apiClient: AdditionalAudienceCheckerAPIClientProtocol? = nil,
        date: AirshipDateProtocol = AirshipDate.shared
    ) {
        self.cache = cache
        self.apiClient = apiClient ?? AdditionalAudienceCheckerAPIClient(config: config)
        self.additionalAudienceConfig = audienceCheckConfig
        self.date = date
    }
    
    func resolve(
        deviceInfoProvider: AudienceDeviceInfoProvider,
        audienceCheckOptions: AudienceCheckOverrides?
    ) async throws -> Bool {
        
        guard
            let config = additionalAudienceConfig,
            config.isEnabled
        else {
            return true
        }

        guard
            let urlString = audienceCheckOptions?.url ?? config.url,
            let url = URL(string: urlString)
        else {
            AirshipLogger.warn("Failed to parse additional audience check url " +
                               String(describing: audienceCheckOptions) + ", " +
                               String(describing: config) + ")")
            throw AirshipErrors.error("Missing additional audience check url")
        }
        
        guard audienceCheckOptions?.bypass != true else {
            AirshipLogger.trace("Additional audience check is bypassed")
            return true
        }
        let context = audienceCheckOptions?.context ?? config.context

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
        deviceInfoProvider: AudienceDeviceInfoProvider
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
