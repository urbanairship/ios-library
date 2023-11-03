/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

protocol FeatureFlagRemoteDataAccessProtocol: Sendable {
    func remoteDataFlagInfo(name: String) async -> RemoteDataFeatureFlagInfo
    var status: RemoteDataSourceStatus { get async }

    func waitForRefresh() async
    func notifyOutdated(remoteDateInfo: RemoteDataInfo?) async
}

final class FeatureFlagRemoteDataAccess: FeatureFlagRemoteDataAccessProtocol {

    private let decoder: JSONDecoder = JSONDecoder()
    private let remoteData: RemoteDataProtocol
    private let date: AirshipDateProtocol



    init(
        remoteData: RemoteDataProtocol,
        date: AirshipDateProtocol = AirshipDate.shared
    ) {
        self.remoteData = remoteData
        self.date = date
    }

    var status: RemoteDataSourceStatus {
        get async {
            return await remoteData.status(source: RemoteDataSource.app)
        }
    }

    func waitForRefresh() async  {
        await remoteData.waitRefresh(source: RemoteDataSource.app, maxTime: 15.0)
    }

    func notifyOutdated(remoteDateInfo: RemoteDataInfo?) async {
        if let remoteDateInfo = remoteDateInfo {
            await remoteData.notifyOutdated(remoteDataInfo: remoteDateInfo)
        }
    }

    func remoteDataFlagInfo(name: String) async -> RemoteDataFeatureFlagInfo {
        let appPayloads = await remoteData.payloads(types: ["feature_flags"])
            .filter { $0.remoteDataInfo?.source == .app }

        let flagInfos = appPayloads
            .compactMap { payload in
                let config = payload.data["feature_flags"] as? [[AnyHashable: Any]]

                return config?
                    .compactMap {
                        do {
                            let data = try JSONSerialization.data(withJSONObject: $0)
                            return try self.decoder.decode(FeatureFlagInfo.self, from: data)
                        } catch {
                            AirshipLogger.error("Unable to parse feature flag \($0), error: \(error)")
                            return nil
                        }
                    }
            }
            .flatMap { $0 }
            .filter { $0.name == name }
            .filter { $0.timeCriteria?.isActive(date: self.date.now) ?? true }


        return RemoteDataFeatureFlagInfo(
            name: name,
            flagInfos: flagInfos,
            remoteDataInfo: appPayloads.first?.remoteDataInfo
        )
    }
}

struct RemoteDataFeatureFlagInfo {
    let name: String
    let flagInfos: [FeatureFlagInfo]
    let remoteDataInfo: RemoteDataInfo?
}


