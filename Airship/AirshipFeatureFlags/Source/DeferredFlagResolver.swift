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

    private let cache: any AirshipCache
    private let deferredResolver: any AirshipDeferredResolverProtocol
    private let date: any AirshipDateProtocol
    private let taskSleeper: any AirshipTaskSleeper

    private var pendingTasks: [String: Task<DeferredFlagResponse, any Error>] = [:]
    private var backOffDates: [String: Date] = [:]

    init(
        cache: any AirshipCache,
        deferredResolver: any AirshipDeferredResolverProtocol,
        date: any AirshipDateProtocol = AirshipDate.shared,
        taskSleeper: any AirshipTaskSleeper = .shared
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

        case .retriableError(let retryAfter):
            let backoff = retryAfter ?? FeatureFlagDeferredResolver.defaultBackoff

            guard allowRetry, backoff <= FeatureFlagDeferredResolver.immediateBackoffRetryCutoff else {
                backOffDates[requestID] = self.date.now.addingTimeInterval(backoff)
                throw FeatureFlagEvaluationError.connectionError
            }

            if (backoff > 0) {
                try await self.taskSleeper.sleep(timeInterval: backoff)
            }

            return try await self.fetchFlag(
                request: request,
                requestID: requestID,
                flagInfo: flagInfo,
                allowRetry: false
            )

        case .outOfDate:
            throw FeatureFlagEvaluationError.outOfDate

        default:
            throw FeatureFlagEvaluationError.connectionError
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
