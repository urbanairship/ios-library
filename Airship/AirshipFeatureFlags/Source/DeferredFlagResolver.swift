/* Copyright Airship and Contributors */

import Foundation
#if canImport(AirshipCore)
import AirshipCore
#endif

protocol FeatureFlagDeferredResolverProtocol: Actor {
    func resolve(
        request: DeferredRequest,
        flagInfo: FeatureFlagInfo
    ) async throws -> DeferredFlagResponse
}

actor FeatureFlagDeferredResolver: FeatureFlagDeferredResolverProtocol {
    private static let minCacheTime: TimeInterval = 60.0

    private static let defaultBackoff: TimeInterval = 30.0
    private static let immediateBackoffRetryCutoff: TimeInterval = 5.0

    private let cache: AirshipCache
    private let deferredResolver: AirshipDeferredResolverProtocol
    private let date: AirshipDateProtocol
    private let taskSleeper: AirshipTaskSleeper

    private var pendingTasks: [String: Task<DeferredFlagResponse, Error>] = [:]
    private var backOffDates: [String: Date] = [:]

    init(
        cache: AirshipCache,
        deferredResolver: AirshipDeferredResolverProtocol,
        date: AirshipDateProtocol = AirshipDate.shared,
        taskSleeper: AirshipTaskSleeper = .shared
    ) {
        self.cache = cache
        self.deferredResolver = deferredResolver
        self.date = date
        self.taskSleeper = taskSleeper
    }

    func resolve(
        request: DeferredRequest,
        flagInfo: FeatureFlagInfo
    ) async throws -> DeferredFlagResponse {

        let requestID = [
            flagInfo.name,
            flagInfo.id,
            "\(flagInfo.lastUpdated.timeIntervalSince1970)",
            request.contactID ?? "",
            request.url.absoluteString,
        ].joined(separator: ":")

        _ = try? await pendingTasks[requestID]?.value

        let task = Task {
            if let cached: DeferredFlagResponse = await self.cache.getCachedValue(key: requestID) {
                return cached
            }

            let result = try await self.fetchFlag(
                request: request,
                requestID: requestID,
                flagInfo: flagInfo,
                allowRetry: true
            )

            var ttl: TimeInterval = FeatureFlagDeferredResolver.minCacheTime
            if let ttlMs = flagInfo.evaluationOptions?.ttlMS {
                let ttlSeconds = Double(ttlMs)/1000
                ttl = max(ttl, ttlSeconds)
            }

            await self.cache.setCachedValue(result, key: requestID, ttl: ttl)
            return result
        }

        pendingTasks[requestID] = task
        return try await task.value
    }

    private func fetchFlag(
        request: DeferredRequest,
        requestID: String,
        flagInfo: FeatureFlagInfo,
        allowRetry: Bool
    ) async throws -> DeferredFlagResponse {
        let now = self.date.now
        if let backOffDate = backOffDates[requestID], backOffDate > now {
            try await self.taskSleeper.sleep(
                timeInterval: backOffDate.timeIntervalSince(now)
            )
        }
        
        let result = await deferredResolver.resolve(request: request) { data in
            return try AirshipJSON.defaultDecoder.decode(DeferredFlag.self, from: data)
        }

        switch(result) {
        case .success(let flag):
            return .found(flag)

        case .notFound:
            return .notFound

        case .retriableError(let retryAfter, let statusCode):
            let backoff = retryAfter ?? FeatureFlagDeferredResolver.defaultBackoff

            guard allowRetry, backoff <= FeatureFlagDeferredResolver.immediateBackoffRetryCutoff else {
                backOffDates[requestID] = self.date.now.advanced(by: backoff)
                if let statusCode = statusCode {
                    throw FeatureFlagEvaluationError.connectionError(errorMessage: "Failed to resolve flag. Status code: \(statusCode)")
                }

                throw FeatureFlagEvaluationError.connectionError(errorMessage: "Failed to resolve flag.")
            }

            if (backoff > 0) {
                AirshipLogger.debug(statusCode == nil ? "Backing off deferred flag request \(requestID) for \(backoff) seconds" : "Backing off deferred flag request \(requestID) for \(backoff) seconds with status code: \(statusCode!)")

                try await self.taskSleeper.sleep(timeInterval: backoff)
            }

            AirshipLogger.error(statusCode == nil ? "Retrying deferred flag request \(requestID)" : "Retrying deferred flag request \(requestID) with status code: \(statusCode!)")

            return try await self.fetchFlag(
                request: request,
                requestID: requestID,
                flagInfo: flagInfo,
                allowRetry: false
            )

        case .outOfDate:
            throw FeatureFlagEvaluationError.outOfDate

        default:
            throw FeatureFlagEvaluationError.connectionError(errorMessage: "Failed to resolve flag.")
        }
    }
}

enum DeferredFlagResponse: Codable, Equatable {
    case notFound
    case found(DeferredFlag)
}

struct DeferredFlag: Codable, Equatable {
    let isEligible: Bool
    let variables: FeatureFlagVariables?
    let reportingMetadata: AirshipJSON
    enum CodingKeys: String, CodingKey {
        case isEligible = "is_eligible"
        case variables = "variables"
        case reportingMetadata = "reporting_metadata"
    }
}
