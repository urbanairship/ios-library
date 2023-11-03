/* Copyright Airship and Contributors */

import Foundation
#if canImport(AirshipCore)
import AirshipCore
#endif

protocol FeatureFlagDeferredResolverProtocol: AnyActor {
    func resolve(
        request: DeferredRequest,
        flagInfo: FeatureFlagInfo
    ) async throws -> FeatureFlag
}

actor FeatureFlagDeferredResolver: FeatureFlagDeferredResolverProtocol {
    private static let minCacheTime: TimeInterval = 60.0

    private static let defaultBackoff: TimeInterval = 30.0
    private static let immediateBackoffRetryCutoff: TimeInterval = 5.0

    private let cache: AirshipCache
    private let deferredResolver: AirshipDeferredResolverProtocol
    private let date: AirshipDateProtocol
    private let taskSleeper: AirshipTaskSleeper

    private var pendingTasks: [String: Task<FeatureFlag, Error>] = [:]
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
    ) async throws -> FeatureFlag {

        let requestID = [
            flagInfo.name,
            flagInfo.id,
            "\(flagInfo.lastUpdated.timeIntervalSince1970)",
            request.contactID ?? "",
            request.url.absoluteString,
        ].joined(separator: ":")

        _ = try? await pendingTasks[requestID]?.value

        let task = Task {
            if let cached: FeatureFlag = await self.cache.getCachedValue(key: requestID) {
                return cached
            }

            let flag = try await self.fetchFlag(
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

            await self.cache.setCachedValue(flag, key: requestID, ttl: ttl)
            return flag
        }

        pendingTasks[requestID] = task
        return try await task.value
    }

    private func fetchFlag(
        request: DeferredRequest,
        requestID: String,
        flagInfo: FeatureFlagInfo,
        allowRetry: Bool
    ) async throws -> FeatureFlag {
        let now = self.date.now
        if let backOffDate = backOffDates[requestID], backOffDate > now {
            try await self.taskSleeper.sleep(
                timeInterval: backOffDate.timeIntervalSince(now)
            )
        }

        let result = await deferredResolver.resolve(request: request) { data in
            return try AirshipJSON.defaultDecoder.decode(DeferredFlagResult.self, from: data)
        }

        switch(result) {
        case .success(let body):
            return FeatureFlag(
                name: flagInfo.name,
                isEligible: body.isEligible,
                exists: true,
                variables: body.variables,
                reportingInfo: FeatureFlag.ReportingInfo(
                    reportingMetadata: body.reportingMetadata,
                    contactID: request.contactID,
                    channelID: request.channelID
                )
            )


        case .notFound:
            return FeatureFlag(
                name: flagInfo.name,
                isEligible: false,
                exists: false,
                variables: nil,
                reportingInfo: nil
            )

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

fileprivate struct DeferredFlagResult : Codable, Equatable {
    let isEligible: Bool
    let variables: AirshipJSON?
    let reportingMetadata: AirshipJSON
    enum CodingKeys: String, CodingKey {
        case isEligible = "is_eligible"
        case variables = "variables"
        case reportingMetadata = "reporting_metadata"
    }
}
