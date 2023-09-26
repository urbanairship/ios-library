/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

protocol FeatureFlagRemoteDataAccessProtocol: Sendable {
    func waitForRefresh() async
    var flagInfos: [FeatureFlagInfo] { get async }
    var status: RemoteDataSourceStatus { get async }

}

final class FeatureFlagRemoteDataAccess: FeatureFlagRemoteDataAccessProtocol {
    var status: RemoteDataSourceStatus {
        get async {
            return await remoteData.status(source: RemoteDataSource.app)
        }
    }

    private let decoder: JSONDecoder = JSONDecoder()
    private let remoteData: RemoteDataProtocol

    func waitForRefresh() async  {
        await remoteData.waitRefresh(source: RemoteDataSource.app, maxTime: 15.0)
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
        remoteData: RemoteDataProtocol
    ) {
        self.remoteData = remoteData
    }
}
