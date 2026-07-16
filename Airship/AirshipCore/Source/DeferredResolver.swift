/* Copyright Airship and Contributors */

@_spi(AirshipInternal) import AirshipBasement

public import Foundation

/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public enum AirshipDeferredResult<T : Sendable&Equatable>: Sendable, Equatable {
    case success(T)
    case timedOut
    case outOfDate
    case notFound
    case retriableError(retryAfter: TimeInterval? = nil, statusCode: Int? = nil)
}

/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
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
        appVersion: String = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "",
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

/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
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

    func resolve<T: Sendable>(
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
        guard let location = header("Location") else {
            return nil
        }

        return URL(string: location)
    }

    var retryAfter: TimeInterval? {
        return retryAfter(now: Date())
    }

    /// Parses the `Retry-After` header into a non-negative wait duration in seconds,
    /// or `nil` if the header is absent or unparseable.
    ///
    /// Accepts (per RFC 7231 §7.1.3, with a permissive extension for fractional seconds):
    ///  - a non-negative integer or decimal number of seconds (e.g. `120`, `1.5`)
    ///  - an RFC 7231 HTTP-date (IMF-fixdate, RFC 850, or asctime)
    ///  - an ISO 8601 timestamp
    ///
    /// Past dates and small negative deltas are clamped to zero.
    func retryAfter(now: Date) -> TimeInterval? {
        guard let raw = header("Retry-After")?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty
        else {
            return nil
        }

        // RFC 7231 §7.1.3: delay-seconds = 1*DIGIT. Permissively accept a decimal
        // fraction. Reject anything number-like but outside the grammar (negative,
        // scientific, leading `+`) so the date parser doesn't mistake `"-5"` for a year.
        if RetryAfterParser.isDelaySeconds(raw), let seconds = Double(raw) {
            return max(0, seconds)
        }
        if Double(raw) != nil {
            return nil
        }

        let parsed = AirshipDateFormatter.date(from: raw)
            ?? RetryAfterParser.parseHttpDate(raw)
        guard let parsed else { return nil }
        return max(0, parsed.timeIntervalSince(now))
    }

    private func header(_ name: String) -> String? {
        return self.headers.first {
            $0.key.caseInsensitiveCompare(name) == .orderedSame
        }?.value
    }
}

fileprivate enum RetryAfterParser {
    /// Returns true if `value` matches the RFC 7231 §7.1.3 delay-seconds grammar
    /// (1*DIGIT), extended to allow a decimal fraction. Rejects negative,
    /// scientific, and leading-`+` number-likes.
    static func isDelaySeconds(_ value: String) -> Bool {
        guard !value.isEmpty else { return false }
        var seenDot = false
        var digitsBefore = 0
        var digitsAfter = 0
        for scalar in value.unicodeScalars {
            switch scalar.value {
            case 0x30...0x39:
                if seenDot { digitsAfter += 1 } else { digitsBefore += 1 }
            case 0x2E:
                if seenDot { return false }
                seenDot = true
            default:
                return false
            }
        }
        return digitsBefore > 0 && (!seenDot || digitsAfter > 0)
    }

    /// RFC 7231 §7.1.1.1 HTTP-date: IMF-fixdate (preferred) and the two obsolete
    /// forms (RFC 850 and asctime). All anchored to GMT/UTC.
    private static let httpDateFormatters: [DateFormatter] = [
        "EEE, dd MMM yyyy HH:mm:ss 'GMT'",
        "EEEE, dd-MMM-yy HH:mm:ss 'GMT'",
        "EEE MMM d HH:mm:ss yyyy",
    ].map { format in
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = format
        return f
    }

    static func parseHttpDate(_ value: String) -> Date? {
        for formatter in httpDateFormatters {
            if let date = formatter.date(from: value) {
                return date
            }
        }
        return nil
    }
}
