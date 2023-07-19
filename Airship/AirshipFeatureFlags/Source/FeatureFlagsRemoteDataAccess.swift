/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

protocol FeatureFlagRemoteDataAccessProtocol: Sendable {
    func refresh() async -> RemoteDataSourceStatus
    var flagInfos: [FeatureFlagInfo] { get async }
}

final class FeatureFlagRemoteDataAccess: FeatureFlagRemoteDataAccessProtocol {
    private let decoder: JSONDecoder = JSONDecoder()
    private let networkChecker: NetworkCheckerProtocol
    private let remoteData: RemoteDataProtocol

    func refresh() async -> RemoteDataSourceStatus {
        let status = await self.remoteData.status(source: .app)
        let isNetworkConnected = await networkChecker.isConnected
        if status == .upToDate || !isNetworkConnected {
            return status
        }

        await remoteData.refresh(source: .app)
        return await remoteData.status(source: .app)
    }

    var flagInfos: [FeatureFlagInfo] {
        get async {
            let appPayloads = await remoteData.payloads(types: ["feature_flags"])
                .filter { $0.remoteDataInfo?.source == .app }

            return appPayloads
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
        }
    }


    init(
        remoteData: RemoteDataProtocol,
        networkChecker: NetworkCheckerProtocol = NetworkChecker()
    ) {
        self.remoteData = remoteData
        self.networkChecker = networkChecker
    }
}
