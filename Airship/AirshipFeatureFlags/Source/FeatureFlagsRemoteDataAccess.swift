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

    init(
        remoteData: any RemoteDataProtocol,
        date: any AirshipDateProtocol = AirshipDate.shared
    ) {
        self.remoteData = remoteData
        self.date = date
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

        let flagInfos: [FeatureFlagInfo] = parsedFlagInfo
            .filter { $0.name == name }
            .filter { $0.timeCriteria?.isActive(date: self.date.now) ?? true }

        return RemoteDataFeatureFlagInfo(
            name: name,
            flagInfos: flagInfos,
            remoteDataInfo: appPayload?.remoteDataInfo
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


