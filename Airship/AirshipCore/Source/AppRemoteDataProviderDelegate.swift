/* Copyright Airship and Contributors */

import Foundation

struct AppRemoteDataProviderDelegate: RemoteDataProviderDelegate {
    let source: RemoteDataSource = .app
    let storeName: String

    private let config: RuntimeConfig
    private let apiClient: any RemoteDataAPIClientProtocol


    init(config: RuntimeConfig, apiClient: any RemoteDataAPIClientProtocol) {
        self.config = config
        self.apiClient = apiClient
        self.storeName = "RemoteData-\(config.appCredentials.appKey).sqlite"
    }

    private func makeURL(locale: Locale, randomValue: Int) throws -> URL {
        return try RemoteDataURLFactory.makeURL(
            config: config,
            path: "/api/remote-data/app/\(config.appCredentials.appKey)/ios",
            locale: locale,
            randomValue: randomValue
        )
    }

    func isRemoteDataInfoUpToDate(_  remoteDataInfo: RemoteDataInfo, locale: Locale, randomValue: Int) async -> Bool {
        let url = try? makeURL(locale: locale, randomValue: randomValue)
        return remoteDataInfo.url == url
    }

    func fetchRemoteData(
        locale: Locale,
        randomValue: Int,
        lastRemoteDataInfo: RemoteDataInfo?
    ) async throws -> AirshipHTTPResponse<RemoteDataResult> {
        let url = try makeURL(locale: locale, randomValue: randomValue)

        var lastModified: String? = nil
        if (lastRemoteDataInfo?.url == url) {
            lastModified = lastRemoteDataInfo?.lastModifiedTime
        }

        return try await self.apiClient.fetchRemoteData(
            url: url,
            auth: .generatedAppToken,
            lastModified: lastModified
        ) { newLastModified in
            return RemoteDataInfo(
                url: url,
                lastModifiedTime: newLastModified,
                source: .app
            )
        }
    }
}





