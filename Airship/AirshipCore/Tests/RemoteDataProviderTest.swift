/* Copyright Airship and Contributors */

import Testing
@_spi(AirshipInternal) import AirshipBasement

@testable
import AirshipCore
import Foundation

@Suite
struct RemoteDataProviderTest {
    private let delegate = TestRemoteDataProviderDelegate(
        source: .app,
        storeName: "RemoteDataProviderTest"
    )

    private let dataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private let provider: RemoteDataProvider

    init() {
        self.provider = RemoteDataProvider(dataStore: self.dataStore, delegate: self.delegate)
    }

    @Test
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
            #expect(lastRemoteInfo == nil)
            #expect(locale == requestLocale)
            #expect(randomValue == requestRandomValue)
            return AirshipHTTPResponse(result: refreshResult, statusCode: 200, headers: [:])
        }

        let result = await self.provider.refresh(
            changeToken: "change",
            locale: locale,
            randomeValue: randomValue
        )
        #expect(result == .newData)

        let payloads = await self.provider.payloads(types: ["some type", "some other type"])
        #expect(refreshResult.payloads == payloads)
    }

    @Test
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
        #expect(refreshResult == .newData)

        var payloads = await self.provider.payloads(types: ["foo"])
        #expect(!(payloads.isEmpty))


        _ = await self.provider.setEnabled(false)

        payloads = await self.provider.payloads(types: ["foo"])
        #expect(payloads.isEmpty)

        // should clear data
        refreshResult = await self.provider.refresh(
            changeToken: "change",
            locale: Locale.current,
            randomeValue: 100
        )
        #expect(refreshResult == .newData)

        // should no-op
        refreshResult = await self.provider.refresh(
            changeToken: "change",
            locale: Locale.current,
            randomeValue: 100
        )
        #expect(refreshResult == .skipped)

        _ = await self.provider.setEnabled(true)
        payloads = await self.provider.payloads(types: ["foo"])
        #expect(payloads.isEmpty)
    }

    @Test
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
        #expect(refreshResult == .newData)
        var payloads = await self.provider.payloads(types: ["foo"])
        #expect(!(payloads.isEmpty))

        // Refresh same data
        self.delegate.isRemoteDataInfoUpToDateCallback = { info, locale, randomValue in
            #expect(remoteDataInfo == info)
            #expect(Locale.current == locale)
            #expect(200 == randomValue)
            return true
        }

        refreshResult = await self.provider.refresh(
            changeToken: "change",
            locale: Locale.current,
            randomeValue: 200
        )
        #expect(refreshResult == .skipped)
        payloads = await self.provider.payloads(types: ["foo"])
        #expect(!(payloads.isEmpty))

        // Change token update
        refreshResult = await self.provider.refresh(
            changeToken: "new change",
            locale: Locale.current,
            randomeValue: 200
        )
        #expect(refreshResult == .newData)
        payloads = await self.provider.payloads(types: ["foo"])
        #expect(!(payloads.isEmpty))

        // Out of date
        self.delegate.isRemoteDataInfoUpToDateCallback = { info, locale, randomValue in
            #expect(remoteDataInfo == info)
            #expect(Locale.current == locale)
            #expect(200 == randomValue)
            return false
        }

        refreshResult = await self.provider.refresh(
            changeToken: "new change",
            locale: Locale.current,
            randomeValue: 200
        )
        #expect(refreshResult == .newData)
        payloads = await self.provider.payloads(types: ["foo"])
        #expect(!(payloads.isEmpty))
    }

    @Test
    func testStatus() async throws {
        let de = Locale(identifier: "de")

        var status: RemoteDataSourceStatus!
        status = await self.provider.status(changeToken: "change", locale: de, randomeValue: 100)
        // No data
        #expect(status == .outOfDate)

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
        #expect(status == .upToDate)

        // Stale
        status = await self.provider.status(changeToken: "some other", locale: de, randomeValue: 100)
        #expect(status == .stale)

        self.delegate.isRemoteDataInfoUpToDateCallback = { info, locale, randomValue in
            return false
        }

        // Out of date from random value
        status = await self.provider.status(changeToken: "change", locale: de, randomeValue: 200)
        #expect(status == .outOfDate)

        // Out of date check over stale
        status = await self.provider.status(changeToken: "some other", locale: de, randomeValue: 100)
        #expect(status == .outOfDate)
    }

    @Test
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
        #expect(refreshResult == .newData)

        // 304
        self.delegate.fetchRemoteDataCallback = { _, _, _ in
            return AirshipHTTPResponse(result: nil, statusCode: 304, headers: [:])
        }

        refreshResult = await self.provider.refresh(
            changeToken: "new change",
            locale: Locale.current,
            randomeValue: 200
        )
        #expect(refreshResult == .skipped)
    }

    @Test
    func testRefresh304WithoutLastModifiedFails() async throws {
        self.delegate.fetchRemoteDataCallback = { _, _, _ in
            return AirshipHTTPResponse(result: nil, statusCode: 304, headers: [:])
        }

        let refreshResult = await self.provider.refresh(
            changeToken: "change",
            locale: Locale.current,
            randomeValue: 100
        )
        #expect(refreshResult == .failed)
    }


    @Test
    func testRefreshClientError() async throws {
        self.delegate.fetchRemoteDataCallback = { _, _, _ in
            return AirshipHTTPResponse(result: nil, statusCode: 400, headers: [:])
        }

        let refreshResult = await self.provider.refresh(
            changeToken: "change",
            locale: Locale.current,
            randomeValue: 100
        )
        #expect(refreshResult == .failed)
    }

    @Test
    func testRefreshServerError() async throws {
        self.delegate.fetchRemoteDataCallback = { _, _, _ in
            return AirshipHTTPResponse(result: nil, statusCode: 500, headers: [:])
        }

        let refreshResult = await self.provider.refresh(
            changeToken: "change",
            locale: Locale.current,
            randomeValue: 100
        )
        #expect(refreshResult == .failed)
    }

    @Test
    func testRefreshThrows() async throws {
        self.delegate.fetchRemoteDataCallback = { _, _, _ in
            throw AirshipErrors.error("some error")
        }

        let refreshResult = await self.provider.refresh(
            changeToken: "change",
            locale: Locale.current,
            randomeValue: 100
        )
        #expect(refreshResult == .failed)
    }

    @Test
    func testNotifyOutdated() async throws {
        let remoteDataInfo = RemoteDataInfo(
            url: URL(string: "example://")!,
            lastModifiedTime: "some last modified",
            source: self.delegate.source
        )

        let requestCount = AirshipAtomicValue<Int>(0)
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
        #expect(refreshResult == .newData)
        #expect(1 == requestCount.value)

        // skipped
        refreshResult = await self.provider.refresh(
            changeToken: "change",
            locale: Locale.current,
            randomeValue: 100
        )
        #expect(refreshResult == .skipped)
        #expect(1 == requestCount.value)


        // Notify different outdated remote info
        _ = await self.provider.notifyOutdated(
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
        #expect(refreshResult == .skipped)
        #expect(1 == requestCount.value)

        // Notify outdated remote info
        _ = await self.provider.notifyOutdated(
            remoteDataInfo: remoteDataInfo
        )

        // Refresh
        refreshResult = await self.provider.refresh(
            changeToken: "change",
            locale: Locale.current,
            randomeValue: 100
        )
        #expect(refreshResult == .newData)
        #expect(2 == requestCount.value)
    }

    @Test
    func testIsCurrent() async throws {
        let remoteDataInfo = RemoteDataInfo(
            url: URL(string: "example://")!,
            lastModifiedTime: "some last modified",
            source: self.delegate.source
        )

        // No data
        var isCurrent = await self.provider.isCurrent(
            locale: Locale.current,
            randomeValue: 100,
            remoteDataInfo: remoteDataInfo
        )
        #expect(!(isCurrent))


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
            #expect(currentInfo == remoteDataInfo)
            #expect(Locale.current == locale)
            #expect(0 == randomValue)
            return true
        }

        isCurrent = await self.provider.isCurrent(locale: Locale.current, randomeValue: 0, remoteDataInfo: remoteDataInfo)
        #expect(isCurrent)

        self.delegate.isRemoteDataInfoUpToDateCallback = { _, _, _ in
            return false
        }

        isCurrent = await self.provider.isCurrent(locale: Locale.current, randomeValue: 0, remoteDataInfo: remoteDataInfo)
        #expect(!(isCurrent))
    }

    @Test
    func testIsCurrentDifferentRemoteDataInfo() async throws {
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
            return true
        }

        var isCurrent = await self.provider.isCurrent(locale: Locale.current, randomeValue: 0, remoteDataInfo: remoteDataInfo)
        #expect(isCurrent)

        let updatedRemoteDataInfo = RemoteDataInfo(
            url: URL(string: "example://")!,
            lastModifiedTime: "some other last modified",
            source: self.delegate.source
        )

        isCurrent = await self.provider.isCurrent(locale: Locale.current, randomeValue: 0, remoteDataInfo: updatedRemoteDataInfo)
        #expect(!(isCurrent))
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
