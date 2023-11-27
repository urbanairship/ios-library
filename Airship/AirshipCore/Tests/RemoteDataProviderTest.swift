/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

class RemoteDataProviderTest: XCTestCase {
    private let delegate = TestRemoteDataProviderDelegate(
        source: .app,
        storeName: "RemoteDataProviderTest"
    )

    private let dataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private var provider: RemoteDataProvider!

    override func setUpWithError() throws {
        self.provider = RemoteDataProvider(dataStore: self.dataStore, delegate: self.delegate)
    }

    func testRefresh() async throws {
        let locale = Locale(identifier: "bs")
        let randomValue = 100

        let remoteDataInfo = RemoteDataInfo(
            url: URL(string: "example://")!,
            lastModifiedTime: "some last modified",
            source: self.delegate.source
        )

        let refreshResult = RemoteDataResult(
            payloads: [
                RemoteDataTestUtils.generatePayload(
                    type: "some type",
                    timestamp: Date(),
                    data: ["cool": "data"],
                    remoteDataInfo: remoteDataInfo
                ),
                RemoteDataTestUtils.generatePayload(
                    type: "some other type",
                    timestamp: Date(),
                    data: ["cool": "data"],
                    remoteDataInfo: remoteDataInfo
                )
            ],
            remoteDataInfo: remoteDataInfo
        )
        
        self.delegate.fetchRemoteDataCallback = { requestLocale, requestRandomValue, lastRemoteInfo in
            XCTAssertNil(lastRemoteInfo)
            XCTAssertEqual(locale, requestLocale)
            XCTAssertEqual(randomValue, requestRandomValue)
            return AirshipHTTPResponse(result: refreshResult, statusCode: 200, headers: [:])
        }

        let result = await self.provider.refresh(
            changeToken: "change",
            locale: locale,
            randomeValue: randomValue
        )
        XCTAssertEqual(result, .newData)

        let payloads = await self.provider.payloads(types: ["some type", "some other type"])
        XCTAssertEqual(refreshResult.payloads, payloads)
    }

    func testRefreshDisabled() async throws {
        let source = self.delegate.source
        self.delegate.fetchRemoteDataCallback = { _, _, _ in
            let remoteDataInfo = RemoteDataInfo(
                url: URL(string: "example://")!,
                lastModifiedTime: "some last modified",
                source: source
            )

            let refreshResult = RemoteDataResult(
                payloads: [
                    RemoteDataTestUtils.generatePayload(
                        type: "foo",
                        timestamp: Date(),
                        data: ["cool": "data"],
                        remoteDataInfo: remoteDataInfo
                    )
                ],
                remoteDataInfo: remoteDataInfo
            )

            return AirshipHTTPResponse(result: refreshResult, statusCode: 200, headers: [:])
        }

        // Load data
        var refreshResult = await self.provider.refresh(
            changeToken: "change",
            locale: Locale.current,
            randomeValue: 100
        )
        XCTAssertEqual(refreshResult, .newData)

        var payloads = await self.provider.payloads(types: ["foo"])
        XCTAssertFalse(payloads.isEmpty)


        _ = await self.provider.setEnabled(false)

        payloads = await self.provider.payloads(types: ["foo"])
        XCTAssertTrue(payloads.isEmpty)

        // should clear data
        refreshResult = await self.provider.refresh(
            changeToken: "change",
            locale: Locale.current,
            randomeValue: 100
        )
        XCTAssertEqual(refreshResult, .newData)

        // should no-op
        refreshResult = await self.provider.refresh(
            changeToken: "change",
            locale: Locale.current,
            randomeValue: 100
        )
        XCTAssertEqual(refreshResult, .skipped)

        _ = await self.provider.setEnabled(true)
        payloads = await self.provider.payloads(types: ["foo"])
        XCTAssertTrue(payloads.isEmpty)
    }

    func testRefreshSkipped() async throws {
        let remoteDataInfo = RemoteDataInfo(
            url: URL(string: "example://")!,
            lastModifiedTime: "some last modified",
            source: self.delegate.source
        )

        self.delegate.fetchRemoteDataCallback = { _, _, _ in
            let refreshResult = RemoteDataResult(
                payloads: [
                    RemoteDataTestUtils.generatePayload(
                        type: "foo",
                        timestamp: Date(),
                        data: ["cool": "data"],
                        remoteDataInfo: remoteDataInfo
                    )
                ],
                remoteDataInfo: remoteDataInfo
            )

            return AirshipHTTPResponse(result: refreshResult, statusCode: 200, headers: [:])
        }

        // Load data
        var refreshResult = await self.provider.refresh(
            changeToken: "change",
            locale: Locale.current,
            randomeValue: 100
        )
        XCTAssertEqual(refreshResult, .newData)
        var payloads = await self.provider.payloads(types: ["foo"])
        XCTAssertFalse(payloads.isEmpty)

        // Refresh same data
        self.delegate.isRemoteDataInfoUpToDateCallback = { info, locale, randomValue in
            XCTAssertEqual(remoteDataInfo, info)
            XCTAssertEqual(Locale.current, locale)
            XCTAssertEqual(200, randomValue)
            return true
        }

        refreshResult = await self.provider.refresh(
            changeToken: "change",
            locale: Locale.current,
            randomeValue: 200
        )
        XCTAssertEqual(refreshResult, .skipped)
        payloads = await self.provider.payloads(types: ["foo"])
        XCTAssertFalse(payloads.isEmpty)

        // Change token update
        refreshResult = await self.provider.refresh(
            changeToken: "new change",
            locale: Locale.current,
            randomeValue: 200
        )
        XCTAssertEqual(refreshResult, .newData)
        payloads = await self.provider.payloads(types: ["foo"])
        XCTAssertFalse(payloads.isEmpty)

        // Out of date
        self.delegate.isRemoteDataInfoUpToDateCallback = { info, locale, randomValue in
            XCTAssertEqual(remoteDataInfo, info)
            XCTAssertEqual(Locale.current, locale)
            XCTAssertEqual(200, randomValue)
            return false
        }

        refreshResult = await self.provider.refresh(
            changeToken: "new change",
            locale: Locale.current,
            randomeValue: 200
        )
        XCTAssertEqual(refreshResult, .newData)
        payloads = await self.provider.payloads(types: ["foo"])
        XCTAssertFalse(payloads.isEmpty)
    }

    func testStatus() async throws {
        let de = Locale(identifier: "de")

        var status: RemoteDataSourceStatus!
        status = await self.provider.status(changeToken: "change", locale: de, randomeValue: 100)
        // No data
        XCTAssertEqual(status, .outOfDate)

        let remoteDataInfo = RemoteDataInfo(
            url: URL(string: "example://")!,
            lastModifiedTime: "some last modified",
            source: self.delegate.source
        )

        // Load data
        self.delegate.fetchRemoteDataCallback = { _, _, _ in
            let refreshResult = RemoteDataResult(
                payloads: [
                    RemoteDataTestUtils.generatePayload(
                        type: "foo",
                        timestamp: Date(),
                        data: ["cool": "data"],
                        remoteDataInfo: remoteDataInfo
                    )
                ],
                remoteDataInfo: remoteDataInfo
            )

            return AirshipHTTPResponse(result: refreshResult, statusCode: 200, headers: [:])
        }

        _ = await self.provider.refresh(
            changeToken: "change",
            locale: Locale.current,
            randomeValue: 100
        )



        // Up to date
        self.delegate.isRemoteDataInfoUpToDateCallback = { info, locale, randomValue in
            return true
        }
        status = await self.provider.status(changeToken: "change", locale: de, randomeValue: 100)
        XCTAssertEqual(status, .upToDate)

        // Stale
        status = await self.provider.status(changeToken: "some other", locale: de, randomeValue: 100)
        XCTAssertEqual(status, .stale)

        self.delegate.isRemoteDataInfoUpToDateCallback = { info, locale, randomValue in
            return false
        }

        // Out of date from random value
        status = await self.provider.status(changeToken: "change", locale: de, randomeValue: 200)
        XCTAssertEqual(status, .outOfDate)

        // Out of date check over stale
        status = await self.provider.status(changeToken: "some other", locale: de, randomeValue: 100)
        XCTAssertEqual(status, .outOfDate)
    }

    func testRefresh304() async throws {
        let remoteDataInfo = RemoteDataInfo(
            url: URL(string: "example://")!,
            lastModifiedTime: "some last modified",
            source: self.delegate.source
        )

        self.delegate.fetchRemoteDataCallback = { _, _, _ in
            let refreshResult = RemoteDataResult(
                payloads: [
                    RemoteDataTestUtils.generatePayload(
                        type: "foo",
                        timestamp: Date(),
                        data: ["cool": "data"],
                        remoteDataInfo: remoteDataInfo
                    )
                ],
                remoteDataInfo: remoteDataInfo
            )

            return AirshipHTTPResponse(result: refreshResult, statusCode: 200, headers: [:])
        }

        // Load data
        var refreshResult = await self.provider.refresh(
            changeToken: "change",
            locale: Locale.current,
            randomeValue: 100
        )
        XCTAssertEqual(refreshResult, .newData)

        // 304
        self.delegate.fetchRemoteDataCallback = { _, _, _ in
            return AirshipHTTPResponse(result: nil, statusCode: 304, headers: [:])
        }

        refreshResult = await self.provider.refresh(
            changeToken: "new change",
            locale: Locale.current,
            randomeValue: 200
        )
        XCTAssertEqual(refreshResult, .skipped)
    }

    func testRefresh304WithoutLastModifiedFails() async throws {
        self.delegate.fetchRemoteDataCallback = { _, _, _ in
            return AirshipHTTPResponse(result: nil, statusCode: 304, headers: [:])
        }

        let refreshResult = await self.provider.refresh(
            changeToken: "change",
            locale: Locale.current,
            randomeValue: 100
        )
        XCTAssertEqual(refreshResult, .failed)
    }


    func testRefreshClientError() async throws {
        self.delegate.fetchRemoteDataCallback = { _, _, _ in
            return AirshipHTTPResponse(result: nil, statusCode: 400, headers: [:])
        }

        let refreshResult = await self.provider.refresh(
            changeToken: "change",
            locale: Locale.current,
            randomeValue: 100
        )
        XCTAssertEqual(refreshResult, .failed)
    }

    func testRefreshServerError() async throws {
        self.delegate.fetchRemoteDataCallback = { _, _, _ in
            return AirshipHTTPResponse(result: nil, statusCode: 500, headers: [:])
        }

        let refreshResult = await self.provider.refresh(
            changeToken: "change",
            locale: Locale.current,
            randomeValue: 100
        )
        XCTAssertEqual(refreshResult, .failed)
    }

    func testRefreshThrows() async throws {
        self.delegate.fetchRemoteDataCallback = { _, _, _ in
            throw AirshipErrors.error("some error")
        }

        let refreshResult = await self.provider.refresh(
            changeToken: "change",
            locale: Locale.current,
            randomeValue: 100
        )
        XCTAssertEqual(refreshResult, .failed)
    }

    func testNotifyOutdated() async throws {
        let remoteDataInfo = RemoteDataInfo(
            url: URL(string: "example://")!,
            lastModifiedTime: "some last modified",
            source: self.delegate.source
        )

        let requestCount = Atomic<Int>(0)
        self.delegate.fetchRemoteDataCallback = { _, _, _ in
            requestCount.value += 1
            let refreshResult = RemoteDataResult(
                payloads: [
                    RemoteDataTestUtils.generatePayload(
                        type: "foo",
                        timestamp: Date(),
                        data: ["cool": "data"],
                        remoteDataInfo: remoteDataInfo
                    )
                ],
                remoteDataInfo: remoteDataInfo
            )

            return AirshipHTTPResponse(result: refreshResult, statusCode: 200, headers: [:])
        }

        self.delegate.isRemoteDataInfoUpToDateCallback = { _, _, _ in
            return true
        }

        // Load data
        var refreshResult = await self.provider.refresh(
            changeToken: "change",
            locale: Locale.current,
            randomeValue: 100
        )
        XCTAssertEqual(refreshResult, .newData)
        XCTAssertEqual(1, requestCount.value)

        // skipped
        refreshResult = await self.provider.refresh(
            changeToken: "change",
            locale: Locale.current,
            randomeValue: 100
        )
        XCTAssertEqual(refreshResult, .skipped)
        XCTAssertEqual(1, requestCount.value)


        // Notify different outdated remote info
        await self.provider.notifyOutdated(
            remoteDataInfo: RemoteDataInfo(
                url: URL(string: "example://")!,
                lastModifiedTime: "some other last modified",
                source: self.delegate.source
            )
        )

        // still skipped
        refreshResult = await self.provider.refresh(
            changeToken: "change",
            locale: Locale.current,
            randomeValue: 100
        )
        XCTAssertEqual(refreshResult, .skipped)
        XCTAssertEqual(1, requestCount.value)

        // Notify outdated remote info
        await self.provider.notifyOutdated(
            remoteDataInfo: remoteDataInfo
        )

        // Refresh
        refreshResult = await self.provider.refresh(
            changeToken: "change",
            locale: Locale.current,
            randomeValue: 100
        )
        XCTAssertEqual(refreshResult, .newData)
        XCTAssertEqual(2, requestCount.value)
    }

    func testIsCurrent() async throws {
        // No data
        var isCurrent = await self.provider.isCurrent(locale: Locale.current, randomeValue: 100)
        XCTAssertFalse(isCurrent)

        let remoteDataInfo = RemoteDataInfo(
            url: URL(string: "example://")!,
            lastModifiedTime: "some last modified",
            source: self.delegate.source
        )

        self.delegate.fetchRemoteDataCallback = { _, _, _ in
            let refreshResult = RemoteDataResult(
                payloads: [],
                remoteDataInfo: remoteDataInfo
            )

            return AirshipHTTPResponse(result: refreshResult, statusCode: 200, headers: [:])
        }

        // Load data
        _ = await self.provider.refresh(
            changeToken: "change",
            locale: Locale.current,
            randomeValue: 0
        )

        self.delegate.isRemoteDataInfoUpToDateCallback = { currentInfo, locale, randomValue in
            XCTAssertEqual(currentInfo, remoteDataInfo)
            XCTAssertEqual(Locale.current, locale)
            XCTAssertEqual(0, randomValue)
            return true
        }

        isCurrent = await self.provider.isCurrent(locale: Locale.current, randomeValue: 0)
        XCTAssertTrue(isCurrent)

        self.delegate.isRemoteDataInfoUpToDateCallback = { _, _, _ in
            return false
        }

        isCurrent = await self.provider.isCurrent(locale: Locale.current, randomeValue: 0)
        XCTAssertFalse(isCurrent)
    }
}

fileprivate class TestRemoteDataProviderDelegate: RemoteDataProviderDelegate, @unchecked Sendable {

    let source: RemoteDataSource
    let storeName: String

    var isRemoteDataInfoUpToDateCallback: (@Sendable (RemoteDataInfo, Locale, Int) async -> Bool)?
    var fetchRemoteDataCallback: (@Sendable (Locale, Int, RemoteDataInfo?) async throws -> AirshipHTTPResponse<RemoteDataResult>)?

    init(source: RemoteDataSource, storeName: String) {
        self.source = source
        self.storeName = storeName
    }

    func isRemoteDataInfoUpToDate(
        _ remoteDataInfo: RemoteDataInfo, locale: Locale, randomValue: Int
    ) async -> Bool {
        return await self.isRemoteDataInfoUpToDateCallback?(remoteDataInfo, locale, randomValue) ?? true
    }

    func fetchRemoteData(locale: Locale, randomValue: Int, lastRemoteDataInfo: RemoteDataInfo?) async throws -> AirshipHTTPResponse<RemoteDataResult> {
        return try await self.fetchRemoteDataCallback!(locale, randomValue, lastRemoteDataInfo)
    }

}
