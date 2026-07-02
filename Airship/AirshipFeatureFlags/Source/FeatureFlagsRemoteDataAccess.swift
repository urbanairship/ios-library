/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

protocol FeatureFlagRemoteDataAccessProtocol: Sendable {
    func remoteDataFlagInfo(name: String) async -> RemoteDataFeatureFlagInfo
    var status: RemoteDataSourceStatus { get async }

    func bestEffortRefresh() async
    func notifyOutdated(remoteDateInfo: RemoteDataInfo?) async
}

final class FeatureFlagRemoteDataAccess: FeatureFlagRemoteDataAccessProtocol {

    private let remoteData: any RemoteDataProtocol
    private let date: any AirshipDateProtocol

    /// Caches the decoded feature flag payload so a burst of concurrent
    /// `remoteDataFlagInfo(name:)` calls shares a single read + decode instead of
    /// each re-reading and re-parsing the whole payload. Validated against the
    /// current remote-data info, and cleared after a period of no use.
    private let payloadCache: AirshipCoalescingCache<CachedFlagInfos>

    init(
        remoteData: any RemoteDataProtocol,
        date: any AirshipDateProtocol = AirshipDate.shared,
        taskSleeper: any AirshipTaskSleeper = .shared,
        cacheIdleTTL: TimeInterval = 10.0
    ) {
        self.remoteData = remoteData
        self.date = date
        self.payloadCache = AirshipCoalescingCache(
            idleTTL: cacheIdleTTL,
            date: date,
            taskSleeper: taskSleeper,
            isValid: { cached in
                guard let remoteDataInfo = cached.remoteDataInfo else { return false }
                return await remoteData.isCurrent(remoteDataInfo: remoteDataInfo)
            },
            load: {
                let appPayload: RemoteDataPayload? = await remoteData.payloads(types: ["feature_flags"])
                    .first { $0.remoteDataInfo?.source == .app }

                let parsedFlagInfo: [FeatureFlagInfo] = appPayload?.data.object?["feature_flags"]?.array?.compactMap { json in
                    do {
                        let flag: FeatureFlagInfo = try json.decode()
                        return flag
                    } catch {
                        AirshipLogger.error("Unable to parse feature flag \(json), error: \(error)")
                        return nil
                    }
                } ?? []

                return CachedFlagInfos(
                    flagInfos: parsedFlagInfo,
                    remoteDataInfo: appPayload?.remoteDataInfo
                )
            }
        )
    }

    var status: RemoteDataSourceStatus {
        get async {
            return await remoteData.status(source: RemoteDataSource.app)
        }
    }

    func bestEffortRefresh() async {
        await remoteData.waitRefresh(source: RemoteDataSource.app, maxTime: 15.0)
    }

    func notifyOutdated(remoteDateInfo: RemoteDataInfo?) async {
        if let remoteDateInfo = remoteDateInfo {
            await remoteData.notifyOutdated(remoteDataInfo: remoteDateInfo)
        }
    }

    func remoteDataFlagInfo(name: String) async -> RemoteDataFeatureFlagInfo {
        // Concurrent callers share a single read + decode via the cache; the cheap
        // `isCurrent` change-token check reloads only when the remote data changed.
        let cached = await payloadCache.value()

        let flagInfos: [FeatureFlagInfo] = cached.flagInfos
            .filter { $0.name == name }
            .filter { $0.timeCriteria?.isActive(date: self.date.now) ?? true }

        return RemoteDataFeatureFlagInfo(
            name: name,
            flagInfos: flagInfos,
            remoteDataInfo: cached.remoteDataInfo
        )
    }
}

struct RemoteDataFeatureFlagInfo {
    let name: String
    let flagInfos: [FeatureFlagInfo]
    let remoteDataInfo: RemoteDataInfo?


    var disallowStale: Bool {
        return flagInfos.contains { flagInfo in
            flagInfo.evaluationOptions?.disallowStaleValue == true
        }
    }
}

/// The decoded feature flag payload, cached between resolutions.
private struct CachedFlagInfos: Sendable {
    let flagInfos: [FeatureFlagInfo]
    let remoteDataInfo: RemoteDataInfo?
}


