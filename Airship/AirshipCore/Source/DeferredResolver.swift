/* Copyright Airship and Contributors */

import Foundation

/// NOTE: For internal use only. :nodoc:
public enum AirshipDeferredResult<T : Sendable&Equatable>: Sendable, Equatable {
    case success(T)
    case timedOut
    case outOfDate
    case notFound
    case retriableError(retryAfter: TimeInterval? = nil, statusCode: Int? = nil)
}

/// NOTE: For internal use only. :nodoc:
public struct DeferredRequest: Sendable, Equatable {
    public var url: URL
    public var channelID: String
    public var contactID: String?
    var triggerContext: AirshipTriggerContext?
    var locale: Locale
    var notificationOptIn: Bool
    var appVersion: String
    var sdkVersion: String

    public init(
        url: URL,
        channelID: String,
        contactID: String? = nil,
        triggerContext: AirshipTriggerContext? = nil,
        locale: Locale,
        notificationOptIn: Bool,
        appVersion: String = AirshipUtils.bundleShortVersionString() ?? "",
        sdkVersion: String = AirshipVersion.version
    ) {
        self.url = url
        self.channelID = channelID
        self.contactID = contactID
        self.triggerContext = triggerContext
        self.locale = locale
        self.notificationOptIn = notificationOptIn
        self.appVersion = appVersion
        self.sdkVersion = sdkVersion
    }
}

/// NOTE: For internal use only. :nodoc:
public protocol AirshipDeferredResolverProtocol : Sendable {
    func resolve<T: Sendable>(
        request: DeferredRequest,
        resultParser: @escaping @Sendable (Data) async throws -> T
    ) async -> AirshipDeferredResult<T>
}

actor AirshipDeferredResolver : AirshipDeferredResolverProtocol {

    private final let audienceOverridesProvider: any AudienceOverridesProvider
    private final let client: any DeferredAPIClientProtocol
    private var locationMap: [URL: URL] = [:]
    private var outdatedURLs: Set<URL> = Set()

    init(
        config: RuntimeConfig,
        audienceOverrides: any AudienceOverridesProvider
    ) {
        self.init(
            client: DeferredAPIClient(config: config),
            audienceOverrides: audienceOverrides
        )
    }
    
    init(
        client: any DeferredAPIClientProtocol,
        audienceOverrides: any AudienceOverridesProvider
    ) {
        self.client = client
        self.audienceOverridesProvider = audienceOverrides
    }

    public func resolve<T: Sendable>(
        request: DeferredRequest,
        resultParser: @escaping @Sendable (Data) async throws -> T
    ) async -> AirshipDeferredResult<T> {
        let audienceOverrides = await audienceOverridesProvider.channelOverrides(
            channelID: request.channelID,
            contactID: request.contactID
        )

        let stateOverrides = AirshipStateOverrides(
            appVersion: request.appVersion,
            sdkVersion: request.sdkVersion,
            notificationOptIn: request.notificationOptIn,
            localeLangauge: request.locale.getLanguageCode(),
            localeCountry: request.locale.getRegionCode()
        )

        return await resolve(
            request: request,
            stateOverrides: stateOverrides,
            audienceOverrides: audienceOverrides,
            resultParser: resultParser,
            allowRetry: true
        )
    }

    private func resolve<T: Sendable>(
        request: DeferredRequest,
        stateOverrides: AirshipStateOverrides,
        audienceOverrides: ChannelAudienceOverrides,
        resultParser: @escaping @Sendable (Data) async throws -> T,
        allowRetry: Bool
    ) async -> AirshipDeferredResult<T> {
        let resolvedURL = self.locationMap[request.url] ?? request.url
        AirshipLogger.trace("Resolving deferred \(resolvedURL)")

        guard !outdatedURLs.contains(resolvedURL) else {
            AirshipLogger.trace("Deferred out of date \(resolvedURL)")
            return .outOfDate
        }
        
        var result: AirshipHTTPResponse<Data>?
        do {
            result = try await client.resolve(
                url: self.locationMap[request.url] ?? request.url,
                channelID: request.channelID,
                contactID: request.contactID,
                stateOverrides: stateOverrides,
                audienceOverrides: audienceOverrides,
                triggerContext: request.triggerContext
            )
        } catch {
            AirshipLogger.trace("Failed to resolve deferred: \(resolvedURL) error: \(error)")
        }

        guard let result = result else {
            AirshipLogger.trace("Resolving deferred timed out \(resolvedURL)")
            return .timedOut
        }
        
        AirshipLogger.trace("Resolving deferred result: \(result)")

        switch (result.statusCode) {
        case 200:
            do {
                guard let body = result.result else {
                    return .retriableError(statusCode: result.statusCode)
                }
                let parsed = try await resultParser(body)

                AirshipLogger.trace("Deferred result body: \(parsed)")

                return .success(parsed)
            } catch {
                AirshipLogger.error("Failed to parse deferred body \(error) with status code: \(result.statusCode)")
                return .retriableError(statusCode: result.statusCode)
            }
        case 404: return .notFound
        case 409:
            outdatedURLs.insert(resolvedURL)
            return .outOfDate
        case 429:
            if let location = result.locationHeader {
                locationMap[request.url] = location
            }
            return .retriableError(retryAfter: result.retryAfter, statusCode: result.statusCode)
        case 307:
            if let location = result.locationHeader {
                locationMap[request.url] = location

                if let retry = result.retryAfter, retry > 0 {
                    return .retriableError(retryAfter: retry, statusCode: result.statusCode)
                }

                if (allowRetry) {
                    return await resolve(
                        request: request,
                        stateOverrides: stateOverrides,
                        audienceOverrides: audienceOverrides,
                        resultParser: resultParser,
                        allowRetry: false
                    )
                }
            }
            return .retriableError(statusCode: result.statusCode)
        default:
            return .retriableError(statusCode: result.statusCode)
        }
    }
}

extension AirshipHTTPResponse {
    var locationHeader: URL? {
        guard let location = self.headers["Location"] else {
            return nil
        }

        return URL(string: location)
    }

    var retryAfter: TimeInterval? {
        guard let retryAfter = self.headers["Retry-After"] else {
            return nil
        }

        if let seconds = Double(retryAfter) {
            return seconds
        }

        return AirshipDateFormatter.date(fromISOString: retryAfter)?.timeIntervalSince1970
    }
}
