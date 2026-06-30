/* Copyright Airship and Contributors */

import Testing
@testable
import AirshipCore
import Foundation

@Suite struct AppRemoteDataProviderDelegateTest {

    private let client: TestRemoteDataAPIClient = TestRemoteDataAPIClient()
    private let config: RuntimeConfig = RuntimeConfig.testConfig()

    private let delegate: AppRemoteDataProviderDelegate

    init() {
        delegate = AppRemoteDataProviderDelegate(config: config, apiClient: client)
    }

    @Test
    func testIsRemoteDataInfoUpToDate() async throws {
        let locale = Locale(identifier: "br")
        let randomValue = 1003

        let remoteDatInfo = RemoteDataInfo(
            url: try RemoteDataURLFactory.makeURL(
                config: config,
                path: "/api/remote-data/app/\(config.appCredentials.appKey)/ios",
                locale: locale,
                randomValue: randomValue
            ),
            lastModifiedTime: "some time",
            source: .app
        )

        var isUpToDate = await self.delegate.isRemoteDataInfoUpToDate(
            remoteDatInfo,
            locale: locale,
            randomValue: randomValue
        )
        #expect(isUpToDate)

        // Different locale
        isUpToDate = await self.delegate.isRemoteDataInfoUpToDate(
            remoteDatInfo,
            locale: Locale(identifier: "en"),
            randomValue: randomValue
        )
        #expect(!(isUpToDate))

        // Different randomValue
        isUpToDate = await self.delegate.isRemoteDataInfoUpToDate(
            remoteDatInfo,
            locale: locale,
            randomValue: randomValue + 1
        )
        #expect(!(isUpToDate))
    }

    @Test
    func testIsRemoteDataInfoUpToDateDifferentURL() async throws {
        let locale = Locale(identifier: "br")
        let randomValue = 1003

        let remoteDatInfo = RemoteDataInfo(
            url: try RemoteDataURLFactory.makeURL(
                config: config,
                path: "/api/remote-data/app/\(config.appCredentials.appKey)/ios/something-else",
                locale: locale,
                randomValue: randomValue
            ),
            lastModifiedTime: "some time",
            source: .app
        )

        let isUpToDate = await self.delegate.isRemoteDataInfoUpToDate(
            remoteDatInfo,
            locale: locale,
            randomValue: randomValue
        )

        #expect(!(isUpToDate))
    }

    @Test
    func testFetch() async throws {
        let locale = Locale(identifier: "br")
        let randomValue = 1003

        let remoteDatInfo = RemoteDataInfo(
            url: try RemoteDataURLFactory.makeURL(
                config: config,
                path: "/api/remote-data/app/\(config.appCredentials.appKey)/ios",
                locale: locale,
                randomValue: randomValue
            ),
            lastModifiedTime: "some time",
            source: .app
        )

        client.lastModified = "some other time"
        client.fetchData = { url, auth, lastModified, info in
            #expect(remoteDatInfo.url == url)
            #expect(AirshipRequestAuth.generatedAppToken == auth)
            #expect("some time" == lastModified)

            let expectedInfo = RemoteDataInfo(
                url: try RemoteDataURLFactory.makeURL(
                    config: self.config,
                    path: "/api/remote-data/app/\(self.config.appCredentials.appKey)/ios",
                    locale: locale,
                    randomValue: randomValue
                ),
                lastModifiedTime: "some other time",
                source: .app
            )
            #expect(expectedInfo == info)

            return AirshipHTTPResponse(
                result: RemoteDataResult(
                    payloads: [],
                    remoteDataInfo: remoteDatInfo
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        let result = try await self.delegate.fetchRemoteData(
            locale: locale,
            randomValue: randomValue,
            lastRemoteDataInfo: remoteDatInfo
        )

        #expect(result.statusCode == 200)
    }

    @Test
    func testFetchLastModifiedOutOfDate() async throws {
        let locale = Locale(identifier: "br")
        let randomValue = 1003

        let remoteDatInfo = RemoteDataInfo(
            url: try RemoteDataURLFactory.makeURL(
                config: config,
                path: "/api/remote-data/app/\(config.appCredentials.appKey)/ios",
                locale: locale,
                randomValue: randomValue
            ),
            lastModifiedTime: "some time",
            source: .app
        )

        client.fetchData = { _, _, lastModified, _ in
            #expect(lastModified == nil)
            return AirshipHTTPResponse(
                result: nil,
                statusCode: 400,
                headers: [:]
            )
        }

        let result = try await self.delegate.fetchRemoteData(
            locale: locale,
            randomValue: randomValue + 1,
            lastRemoteDataInfo: remoteDatInfo
        )

        #expect(result.statusCode == 400)
    }
}
