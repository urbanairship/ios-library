/* Copyright Airship and Contributors */

import XCTest
@testable
import AirshipCore

final class AppRemoteDataProviderDelegateTest: XCTestCase {

    private let client: TestRemoteDataAPIClient = TestRemoteDataAPIClient()
    private let config: RuntimeConfig = {
        var config = AirshipConfig()
        config.defaultAppKey = "test-app-key";
        config.defaultAppSecret = "test-app-secret";
        return RuntimeConfig(
            config: config,
            dataStore: PreferenceDataStore(
                appKey: UUID().uuidString
            )
        )
    }()

    private var delegate: AppRemoteDataProviderDelegate!

    override func setUpWithError() throws {
        delegate = AppRemoteDataProviderDelegate(config: config, apiClient: client)
    }

    func testIsRemoteDataInfoUpToDate() async throws {
        let locale = Locale(identifier: "br")
        let randomValue = 1003

        let remoteDatInfo = RemoteDataInfo(
            url: try RemoteDataURLFactory.makeURL(
                config: config,
                path: "/api/remote-data/app/\(config.appKey)/ios",
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
        XCTAssertTrue(isUpToDate)

        // Different locale
        isUpToDate = await self.delegate.isRemoteDataInfoUpToDate(
            remoteDatInfo,
            locale: Locale(identifier: "en"),
            randomValue: randomValue
        )
        XCTAssertFalse(isUpToDate)

        // Different randomValue
        isUpToDate = await self.delegate.isRemoteDataInfoUpToDate(
            remoteDatInfo,
            locale: locale,
            randomValue: randomValue + 1
        )
        XCTAssertFalse(isUpToDate)
    }

    func testIsRemoteDataInfoUpToDateDifferentURL() async throws {
        let locale = Locale(identifier: "br")
        let randomValue = 1003

        let remoteDatInfo = RemoteDataInfo(
            url: try RemoteDataURLFactory.makeURL(
                config: config,
                path: "/api/remote-data/app/\(config.appKey)/ios/something-else",
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

        XCTAssertFalse(isUpToDate)
    }

    func testFetch() async throws {
        let locale = Locale(identifier: "br")
        let randomValue = 1003

        let remoteDatInfo = RemoteDataInfo(
            url: try RemoteDataURLFactory.makeURL(
                config: config,
                path: "/api/remote-data/app/\(config.appKey)/ios",
                locale: locale,
                randomValue: randomValue
            ),
            lastModifiedTime: "some time",
            source: .app
        )

        client.lastModified = "some other time"
        client.fetchData = { url, auth, lastModified, info in
            XCTAssertEqual(remoteDatInfo.url, url)
            XCTAssertEqual(AirshipRequestAuth.generatedAppToken, auth)
            XCTAssertEqual("some time", lastModified)

            XCTAssertEqual(
                RemoteDataInfo(
                    url: try RemoteDataURLFactory.makeURL(
                        config: self.config,
                        path: "/api/remote-data/app/\(self.config.appKey)/ios",
                        locale: locale,
                        randomValue: randomValue
                    ),
                    lastModifiedTime: "some other time",
                    source: .app
                ),
                info
            )

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

        XCTAssertEqual(result.statusCode, 200)
    }

    func testFetchLastModifiedOutOfDate() async throws {
        let locale = Locale(identifier: "br")
        let randomValue = 1003

        let remoteDatInfo = RemoteDataInfo(
            url: try RemoteDataURLFactory.makeURL(
                config: config,
                path: "/api/remote-data/app/\(config.appKey)/ios",
                locale: locale,
                randomValue: randomValue
            ),
            lastModifiedTime: "some time",
            source: .app
        )

        client.fetchData = { _, _, lastModified, _ in
            XCTAssertNil(lastModified)
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

        XCTAssertEqual(result.statusCode, 400)
    }
}
