/* Copyright Airship and Contributors */

import Foundation
import Testing

@testable
@_spi(AirshipInternal) import AirshipCore

// MARK: - Utils

/// Records sleep intervals without real delays.
private actor RecordingTaskSleeper: AirshipTaskSleeper {
    private(set) var sleepIntervals: [TimeInterval] = []

    func sleep(timeInterval: TimeInterval) async throws {
        sleepIntervals.append(timeInterval)
    }
}

private struct EmptyCachedAssetsForTest: AirshipCachedAssetsProtocol {
    func cachedURL(remoteURL: URL) -> URL? { nil }
    func isCached(remoteURL: URL) -> Bool { false }
}

/// Records `cacheAssets` calls; can throw to simulate failed prefetch/download.
private actor MockAssetCacheManager: AssetCacheManagerProtocol {
    private(set) var cacheAssetsInvocations: [(identifier: String, assets: [String])] = []
    private let prefetchError: Error?

    /// - Parameter prefetchError: Pass non-`nil` to make `cacheAssets` throw; `nil` means success.
    init(prefetchError: Error? = nil) {
        self.prefetchError = prefetchError
    }

    func cacheAssets(
        identifier: String,
        assets: [String]
    ) async throws -> any AirshipCachedAssetsProtocol {
        cacheAssetsInvocations.append((identifier, assets))
        if let prefetchError {
            throw prefetchError
        }
        return EmptyCachedAssetsForTest()
    }

    func clearCache(identifier: String) async {}
}

/// Fails the first `cacheAssets` call, then succeeds (for prefetch-only retry tests).
private actor MockAssetCacheManagerFailOnce: AssetCacheManagerProtocol {
    private(set) var cacheAssetsInvocationCount = 0
    private(set) var cacheAssetsInvocations: [(identifier: String, assets: [String])] = []

    func cacheAssets(
        identifier: String,
        assets: [String]
    ) async throws -> any AirshipCachedAssetsProtocol {
        cacheAssetsInvocationCount += 1
        cacheAssetsInvocations.append((identifier, assets))
        if cacheAssetsInvocationCount == 1 {
            throw URLError(.cannotConnectToHost)
        }
        return EmptyCachedAssetsForTest()
    }

    func clearCache(identifier: String) async {}
}

@MainActor
private final class StubThomasDelegate: ThomasDelegate {
    func onVisibilityChanged(isVisible: Bool, isForegrounded: Bool) {}
    func onReportingEvent(_ event: ThomasReportingEvent) {}
    func onDismissed(cancel: Bool) {}
}

// MARK: - Tests

@Suite("ThomasAsyncViewState", .serialized)
@MainActor
struct ThomasAsyncViewStateTest {

    private var validViewInfoJSONData: Data {
        let json = """
        {
          "type": "empty_view",
          "background_color": {
            "default": {
              "type": "hex",
              "hex": "#00FF00",
              "alpha": 0.5
            }
          }
        }
        """
        return Data(json.utf8)
    }

    /// Minimal media view with an invalid image URL so prefetch fails without slow network retries.
    private var invalidImageUrlViewInfoJSONData: Data {
        let json = """
        {
          "media_fit": "center_inside",
          "media_type": "image",
          "type": "media",
          "url": ":::invalid"
        }
        """
        return Data(json.utf8)
    }

    /// Media image with a syntactically valid HTTPS URL (prefetch mock can succeed without network).
    private var validImageUrlMediaViewInfoJSONData: Data {
        let json = """
        {
          "media_fit": "center_inside",
          "media_type": "image",
          "type": "media",
          "url": "https://cdn.example.com/async-asset.png"
        }
        """
        return Data(json.utf8)
    }

    private func httpResponse(statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://example.com/async-view")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: [:]
        )!
    }

    private func makeProperties(
        retry: ThomasViewInfo.AsyncViewController.RetryingConfig? = nil,
        auth: ThomasViewInfo.AsyncViewController.Request.Auth? = nil,
        identifier: String = "test-async-resolve"
    ) throws -> ThomasViewInfo.AsyncViewController.Properties {
        let placeholder = try JSONDecoder().decode(ThomasViewInfo.self, from: validViewInfoJSONData)
        let retryConfig = retry ?? ThomasViewInfo.AsyncViewController.RetryingConfig(
            maxRetries: 0,
            initialBackoff: 1.0,
            maxBackoff: 10.0
        )
        return ThomasViewInfo.AsyncViewController.Properties(
            retry: retryConfig,
            request: .content(
                .init(
                    url: URL(string: "https://example.com/async-view")!,
                    auth: auth
                )
            ),
            placeholder: placeholder,
            identifier: identifier
        )
    }

    /// Retain the returned value for the duration of the test: `ThomasAsyncViewState` only keeps a weak reference.
    private func environmentWithImageCache() -> ThomasEnvironment {
        ThomasEnvironment(
            delegate: StubThomasDelegate(),
            extensions: ThomasExtensions(
                imageProvider: ExtendableAssetCacheImageProvider()
            )
        )
    }

    @Test
    func appAuth() async throws {
        let testSession = TestAirshipRequestSession()
        testSession.responseScript = [(response: httpResponse(statusCode: 200), data: validViewInfoJSONData)]
        let state = ThomasAsyncViewState(
            properties: try makeProperties(auth: .app),
            taskSleeper: RecordingTaskSleeper(),
            requestSession: testSession
        )
        try await state.resolve()
        #expect(testSession.lastRequest?.auth == .generatedAppToken)
    }

    @Test
    func channelAuth() async throws {
        let testSession = TestAirshipRequestSession()
        testSession.responseScript = [(response: httpResponse(statusCode: 200), data: validViewInfoJSONData)]
        let state = ThomasAsyncViewState(
            properties: try makeProperties(auth: .channel),
            taskSleeper: RecordingTaskSleeper(),
            requestSession: testSession,
            channelIdFetcher: { "injected-channel-id" }
        )
        try await state.resolve()
        #expect(testSession.lastRequest?.auth == .generatedChannelToken(identifier: "injected-channel-id"))
    }

    @Test
    func contactAuth() async throws {
        let testSession = TestAirshipRequestSession()
        testSession.responseScript = [(response: httpResponse(statusCode: 200), data: validViewInfoJSONData)]
        let state = ThomasAsyncViewState(
            properties: try makeProperties(auth: .contact),
            taskSleeper: RecordingTaskSleeper(),
            requestSession: testSession,
            contactIdFetcher: { "injected-contact-id" }
        )
        try await state.resolve()
        #expect(testSession.lastRequest?.auth == .contactAuthToken(identifier: "injected-contact-id"))
    }

    @Test
    func resolveSucceedsOnFirstAttempt() async throws {
        let testSession = TestAirshipRequestSession()
        testSession.responseScript = [(response: httpResponse(statusCode: 200), data: validViewInfoJSONData)]
        let state = ThomasAsyncViewState(
            properties: try makeProperties(),
            taskSleeper: RecordingTaskSleeper(),
            requestSession: testSession
        )
        try await state.resolve()
        #expect(state.response != nil)
        #expect(testSession.requestInvocationCount == 1)
    }

    @Test
    func resolveDoesNotRetryOnNonServerHTTPError() async throws {
        let testSession = TestAirshipRequestSession()
        let sleeper = RecordingTaskSleeper()
        testSession.responseScript = [
            (response: httpResponse(statusCode: 404), data: nil),
            (response: httpResponse(statusCode: 200), data: validViewInfoJSONData)
        ]
        let retry = ThomasViewInfo.AsyncViewController.RetryingConfig(
            maxRetries: 3,
            initialBackoff: 0.25,
            maxBackoff: 100.0
        )
        let state = ThomasAsyncViewState(
            properties: try makeProperties(retry: retry),
            taskSleeper: sleeper,
            requestSession: testSession
        )
        await #expect(throws: (any Error).self) {
            try await state.resolve()
        }
        #expect(testSession.requestInvocationCount == 1)
        let intervals = await sleeper.sleepIntervals
        #expect(intervals.count == 1)
        #expect(intervals[0] == 0)
    }

    @Test
    func resolveRetriesWithExponentialBackoffThenSucceeds() async throws {
        let testSession = TestAirshipRequestSession()
        let sleeper = RecordingTaskSleeper()
        testSession.responseScript = [
            (response: httpResponse(statusCode: 500), data: nil),
            (response: httpResponse(statusCode: 500), data: nil),
            (response: httpResponse(statusCode: 200), data: validViewInfoJSONData)
        ]
        let retry = ThomasViewInfo.AsyncViewController.RetryingConfig(
            maxRetries: 3,
            initialBackoff: 0.25,
            maxBackoff: 100.0
        )
        let state = ThomasAsyncViewState(
            properties: try makeProperties(retry: retry),
            taskSleeper: sleeper,
            requestSession: testSession
        )
        try await state.resolve()
        #expect(state.response != nil)
        #expect(testSession.requestInvocationCount == 3)
        let intervals = await sleeper.sleepIntervals
        #expect(intervals.count == 3)
        #expect(intervals[0] == 0)
        #expect(abs(intervals[1] - 0.25) < 0.0001)
        #expect(abs(intervals[2] - 0.5) < 0.0001)
    }

    @Test
    func resolveExhaustsRetriesAndThrowsServerError() async throws {
        let testSession = TestAirshipRequestSession()
        let sleeper = RecordingTaskSleeper()
        testSession.responseScript = [
            (response: httpResponse(statusCode: 503), data: nil),
            (response: httpResponse(statusCode: 503), data: nil)
        ]
        let retry = ThomasViewInfo.AsyncViewController.RetryingConfig(
            maxRetries: 1,
            initialBackoff: 0.1,
            maxBackoff: 10.0
        )
        let state = ThomasAsyncViewState(
            properties: try makeProperties(retry: retry),
            taskSleeper: sleeper,
            requestSession: testSession
        )
        await #expect(throws: (any Error).self) {
            try await state.resolve()
        }
        #expect(state.response == nil)
        #expect(testSession.requestInvocationCount == 2)
        let intervals = await sleeper.sleepIntervals
        #expect(intervals.count == 2)
        #expect(intervals[0] == 0)
        
    }

    @Test
    func resolveWithMaxRetriesZeroPerformsSingleAttempt() async throws {
        let testSession = TestAirshipRequestSession()
        let sleeper = RecordingTaskSleeper()
        testSession.responseScript = [(response: httpResponse(statusCode: 500), data: nil)]
        let retry = ThomasViewInfo.AsyncViewController.RetryingConfig(
            maxRetries: 0,
            initialBackoff: 1.0,
            maxBackoff: 10.0
        )
        let state = ThomasAsyncViewState(
            properties: try makeProperties(retry: retry),
            taskSleeper: sleeper,
            requestSession: testSession
        )
        await #expect(throws: (any Error).self) {
            try await state.resolve()
        }
        #expect(testSession.requestInvocationCount == 1)
        #expect(await sleeper.sleepIntervals.count == 1)
    }

    @Test
    func resolveNilPropertiesThrows() async throws {
        let state = ThomasAsyncViewState(
            properties: nil,
            taskSleeper: RecordingTaskSleeper(),
            requestSession: TestAirshipRequestSession()
        )
        await #expect(throws: (any Error).self) {
            try await state.resolve()
        }
    }

    /// When prefetch is required, a failed download does not publish `response`; layout is retained for retry.
    @Test
    func resolveFailsWhenImageAssetPrefetchFailsAndKeepsPendingLayout() async throws {
        let testSession = TestAirshipRequestSession()
        testSession.responseScript = [(response: httpResponse(statusCode: 200), data: invalidImageUrlViewInfoJSONData)]
        let cacheManager = MockAssetCacheManager(prefetchError: URLError(.cannotConnectToHost))
        let state = ThomasAsyncViewState(
            properties: try makeProperties(),
            taskSleeper: RecordingTaskSleeper(),
            requestSession: testSession,
            assetCacheManager: cacheManager
        )
        let thomasEnvironment = environmentWithImageCache()
        state.configure(thomasEnvironment: thomasEnvironment)

        await #expect(throws: (any Error).self) {
            try await state.resolve()
        }
        #expect(state.response == nil)
        #expect(state.resolvedLayoutAwaitingPrefetch != nil)
        #expect(testSession.requestInvocationCount == 1)

        let invocations = await cacheManager.cacheAssetsInvocations
        #expect(invocations.count == 1)
        #expect(invocations[0].identifier == "test-async-resolve")
        #expect(invocations[0].assets == [":::invalid"])
    }

    @Test
    func retryAfterPrefetchFailureRetriesPrefetchWithoutSecondHTTPRequest() async throws {
        let testSession = TestAirshipRequestSession()
        testSession.responseScript = [(response: httpResponse(statusCode: 200), data: invalidImageUrlViewInfoJSONData)]
        let cacheManager = MockAssetCacheManagerFailOnce()
        let state = ThomasAsyncViewState(
            properties: try makeProperties(),
            taskSleeper: RecordingTaskSleeper(),
            requestSession: testSession,
            assetCacheManager: cacheManager
        )
        let thomasEnvironment = environmentWithImageCache()
        state.configure(thomasEnvironment: thomasEnvironment)

        await #expect(throws: (any Error).self) {
            try await state.resolve()
        }
        #expect(testSession.requestInvocationCount == 1)
        #expect(state.resolvedLayoutAwaitingPrefetch != nil)

        state.retry()
        for _ in 0..<400 {
            if case .loaded = state.status { break }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        #expect(state.response != nil)
        #expect(state.status == .loaded)
        #expect(state.resolvedLayoutAwaitingPrefetch == nil)
        #expect(testSession.requestInvocationCount == 1)
        #expect(await cacheManager.cacheAssetsInvocationCount == 2)
    }

    // MARK: - Async view assets

    @Test
    func resolvePrefetchInvokesCacheWithDecodedImageUrlsBeforePublishingResponse() async throws {
        let testSession = TestAirshipRequestSession()
        testSession.responseScript = [(response: httpResponse(statusCode: 200), data: validImageUrlMediaViewInfoJSONData)]
        let cacheManager = MockAssetCacheManager()
        let state = ThomasAsyncViewState(
            properties: try makeProperties(identifier: "scene-asset-id"),
            taskSleeper: RecordingTaskSleeper(),
            requestSession: testSession,
            assetCacheManager: cacheManager
        )
        let thomasEnvironment = environmentWithImageCache()
        state.configure(thomasEnvironment: thomasEnvironment)

        try await state.resolve()

        #expect(state.response != nil)
        #expect(state.resolvedLayoutAwaitingPrefetch == nil)
        let invocations = await cacheManager.cacheAssetsInvocations
        #expect(invocations.count == 1)
        #expect(invocations[0].identifier == "scene-asset-id")
        #expect(invocations[0].assets == ["https://cdn.example.com/async-asset.png"])
    }

    @Test
    func resolveWithNoImageUrlsDoesNotInvokeAssetCacheWhenImageProviderPresent() async throws {
        let testSession = TestAirshipRequestSession()
        testSession.responseScript = [(response: httpResponse(statusCode: 200), data: validViewInfoJSONData)]
        let cacheManager = MockAssetCacheManager()
        let state = ThomasAsyncViewState(
            properties: try makeProperties(),
            taskSleeper: RecordingTaskSleeper(),
            requestSession: testSession,
            assetCacheManager: cacheManager
        )
        let thomasEnvironment = environmentWithImageCache()
        state.configure(thomasEnvironment: thomasEnvironment)

        try await state.resolve()

        #expect(state.response != nil)
        #expect(await cacheManager.cacheAssetsInvocations.isEmpty)
    }

    @Test
    func resolveSkipsPrefetchWhenThomasEnvironmentNotConfigured() async throws {
        let testSession = TestAirshipRequestSession()
        testSession.responseScript = [(response: httpResponse(statusCode: 200), data: validImageUrlMediaViewInfoJSONData)]
        let cacheManager = MockAssetCacheManager()
        let state = ThomasAsyncViewState(
            properties: try makeProperties(),
            taskSleeper: RecordingTaskSleeper(),
            requestSession: testSession,
            assetCacheManager: cacheManager
        )

        try await state.resolve()

        #expect(state.response != nil)
        #expect(await cacheManager.cacheAssetsInvocations.isEmpty)
    }

    @Test
    func resolveSkipsPrefetchWhenImageProviderIsNil() async throws {
        let testSession = TestAirshipRequestSession()
        testSession.responseScript = [(response: httpResponse(statusCode: 200), data: validImageUrlMediaViewInfoJSONData)]
        let cacheManager = MockAssetCacheManager()
        let state = ThomasAsyncViewState(
            properties: try makeProperties(),
            taskSleeper: RecordingTaskSleeper(),
            requestSession: testSession,
            assetCacheManager: cacheManager
        )
        let env = ThomasEnvironment(
            delegate: StubThomasDelegate(),
            extensions: ThomasExtensions(imageProvider: nil)
        )
        state.configure(thomasEnvironment: env)

        try await state.resolve()

        #expect(state.response != nil)
        #expect(await cacheManager.cacheAssetsInvocations.isEmpty)
    }

    @Test
    func retryMapsAssetPrefetchFailureToImagePrefetchFailedStatus() async throws {
        let testSession = TestAirshipRequestSession()
        testSession.responseScript = [(response: httpResponse(statusCode: 200), data: invalidImageUrlViewInfoJSONData)]
        let cacheManager = MockAssetCacheManager(prefetchError: URLError(.cannotConnectToHost))
        let state = ThomasAsyncViewState(
            properties: try makeProperties(),
            taskSleeper: RecordingTaskSleeper(),
            requestSession: testSession,
            assetCacheManager: cacheManager
        )
        let thomasEnvironment = environmentWithImageCache()
        state.configure(thomasEnvironment: thomasEnvironment)

        state.retry()
        for _ in 0..<400 {
            if case .error = state.status { break }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        #expect(state.status == .error(.imagePrefetchFailed))
        #expect(state.response == nil)
        #expect(state.resolvedLayoutAwaitingPrefetch != nil)
    }

    @Test
    func startResolveLoadsContentAndSetsLoadedStatus() async throws {
        let testSession = TestAirshipRequestSession()
        testSession.responseScript = [(response: httpResponse(statusCode: 200), data: validViewInfoJSONData)]
        let state = ThomasAsyncViewState(
            properties: try makeProperties(),
            taskSleeper: RecordingTaskSleeper(),
            requestSession: testSession
        )
        state.retry()
        for _ in 0..<400 {
            if case .loaded = state.status { break }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        #expect(state.response != nil)
        #expect(state.status == .loaded)
        #expect(testSession.requestInvocationCount == 1)
    }

    @Test
    func startResolveDoesNothingAfterSuccessfulResolve() async throws {
        let testSession = TestAirshipRequestSession()
        testSession.responseScript = [(response: httpResponse(statusCode: 200), data: invalidImageUrlViewInfoJSONData)]
        let state = ThomasAsyncViewState(
            properties: try makeProperties(),
            taskSleeper: RecordingTaskSleeper(),
            requestSession: testSession
        )
        try await state.resolve()
        #expect(testSession.requestInvocationCount == 1)
        state.retry()
        try await Task.sleep(nanoseconds: 20_000_000)
        #expect(testSession.requestInvocationCount == 1)
        #expect(state.response != nil)
    }

    @Test
    func startResolveMapsFinalServerErrorToStatus() async throws {
        let testSession = TestAirshipRequestSession()
        testSession.responseScript = [(response: httpResponse(statusCode: 404), data: nil)]
        let retry = ThomasViewInfo.AsyncViewController.RetryingConfig(
            maxRetries: 0,
            initialBackoff: 0.01,
            maxBackoff: 1.0
        )
        let state = ThomasAsyncViewState(
            properties: try makeProperties(retry: retry),
            taskSleeper: RecordingTaskSleeper(),
            requestSession: testSession
        )
        state.retry()
        for _ in 0..<400 {
            if case .error = state.status { break }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        #expect(state.status == .error(.server(statusCode: 404)))
    }
}
