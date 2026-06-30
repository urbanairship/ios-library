/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Testing

@testable @_spi(AirshipInternal) import AirshipBasement
@testable @_spi(AirshipInternal) import AirshipSceneRenderer

// MARK: - Utils

/// Records sleep intervals without real delays.
private actor RecordingTaskSleeper: AirshipTaskSleeper {
    private(set) var sleepIntervals: [TimeInterval] = []

    func sleep(timeInterval: TimeInterval) async throws {
        sleepIntervals.append(timeInterval)
    }
}

/// Scriptable async-view resolver: returns canned payloads or throws per call, recording the
/// auth it was asked for. Replaces the old request-session mock now that network/auth lives in
/// the host resolver.
@MainActor
private final class TestAsyncViewResolver: AsyncViewResolver {
    var script: [Result<Data, AsyncViewResolverError>] = []
    private(set) var receivedAuths: [ThomasAsyncViewAuth] = []
    private(set) var callCount = 0

    func resolve(url: URL, auth: ThomasAsyncViewAuth) async throws -> Data {
        receivedAuths.append(auth)
        let result = script[min(callCount, script.count - 1)]
        callCount += 1
        switch result {
        case .success(let data):
            return data
        case .failure(let error):
            throw error
        }
    }
}

/// Spy image loader that records `prefetch` calls and can simulate prefetch failures.
@MainActor
private final class StubThomasImageLoader: ThomasImageLoader {
    private(set) var prefetchInvocations: [[String]] = []
    private let prefetchError: (any Error)?
    private var prefetchFailuresRemaining: Int

    init(
        prefetchError: (any Error)? = nil,
        prefetchFailuresRemaining: Int = 0
    ) {
        self.prefetchError = prefetchError
        self.prefetchFailuresRemaining = prefetchFailuresRemaining
    }

    func load(url: String) async throws -> AirshipImageData { throw CancellationError() }

    func prefetch(urls: [String]) async throws {
        prefetchInvocations.append(urls)
        if prefetchFailuresRemaining > 0 {
            prefetchFailuresRemaining -= 1
            throw URLError(.cannotConnectToHost)
        }
        if let prefetchError {
            throw prefetchError
        }
    }

    func releaseAll() {}
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

    private func resolver(_ script: [Result<Data, AsyncViewResolverError>]) -> TestAsyncViewResolver {
        let resolver = TestAsyncViewResolver()
        resolver.script = script
        return resolver
    }

    @Test
    func appAuth() async throws {
        let testResolver = resolver([.success(validViewInfoJSONData)])
        let state = ThomasAsyncViewState(
            properties: try makeProperties(auth: .app),
            resolver: testResolver,
            taskSleeper: RecordingTaskSleeper()
        )
        try await state.resolve()
        #expect(testResolver.receivedAuths.last == .app)
    }

    @Test
    func channelAuth() async throws {
        let testResolver = resolver([.success(validViewInfoJSONData)])
        let state = ThomasAsyncViewState(
            properties: try makeProperties(auth: .channel),
            resolver: testResolver,
            taskSleeper: RecordingTaskSleeper()
        )
        try await state.resolve()
        #expect(testResolver.receivedAuths.last == .channel)
    }

    @Test
    func contactAuth() async throws {
        let testResolver = resolver([.success(validViewInfoJSONData)])
        let state = ThomasAsyncViewState(
            properties: try makeProperties(auth: .contact),
            resolver: testResolver,
            taskSleeper: RecordingTaskSleeper()
        )
        try await state.resolve()
        #expect(testResolver.receivedAuths.last == .contact)
    }

    @Test
    func noAuthMapsToNone() async throws {
        let testResolver = resolver([.success(validViewInfoJSONData)])
        let state = ThomasAsyncViewState(
            properties: try makeProperties(auth: nil),
            resolver: testResolver,
            taskSleeper: RecordingTaskSleeper()
        )
        try await state.resolve()
        #expect(testResolver.receivedAuths.last == ThomasAsyncViewAuth.none)
    }

    @Test
    func resolveSucceedsOnFirstAttempt() async throws {
        let testResolver = resolver([.success(validViewInfoJSONData)])
        let state = ThomasAsyncViewState(
            properties: try makeProperties(),
            resolver: testResolver,
            taskSleeper: RecordingTaskSleeper()
        )
        try await state.resolve()
        #expect(state.response != nil)
        #expect(testResolver.callCount == 1)
    }

    @Test
    func resolveDoesNotRetryOnNonServerHTTPError() async throws {
        let sleeper = RecordingTaskSleeper()
        let testResolver = resolver([
            .failure(.server(statusCode: 404)),
            .success(validViewInfoJSONData)
        ])
        let retry = ThomasViewInfo.AsyncViewController.RetryingConfig(
            maxRetries: 3,
            initialBackoff: 0.25,
            maxBackoff: 100.0
        )
        let state = ThomasAsyncViewState(
            properties: try makeProperties(retry: retry),
            resolver: testResolver,
            taskSleeper: sleeper
        )
        await #expect(throws: (any Error).self) {
            try await state.resolve()
        }
        #expect(testResolver.callCount == 1)
        let intervals = await sleeper.sleepIntervals
        #expect(intervals.count == 1)
        #expect(intervals[0] == 0)
    }

    @Test
    func resolveRetriesWithExponentialBackoffThenSucceeds() async throws {
        let sleeper = RecordingTaskSleeper()
        let testResolver = resolver([
            .failure(.server(statusCode: 500)),
            .failure(.server(statusCode: 500)),
            .success(validViewInfoJSONData)
        ])
        let retry = ThomasViewInfo.AsyncViewController.RetryingConfig(
            maxRetries: 3,
            initialBackoff: 0.25,
            maxBackoff: 100.0
        )
        let state = ThomasAsyncViewState(
            properties: try makeProperties(retry: retry),
            resolver: testResolver,
            taskSleeper: sleeper
        )
        try await state.resolve()
        #expect(state.response != nil)
        #expect(testResolver.callCount == 3)
        let intervals = await sleeper.sleepIntervals
        #expect(intervals.count == 3)
        #expect(intervals[0] == 0)
        #expect(abs(intervals[1] - 0.25) < 0.0001)
        #expect(abs(intervals[2] - 0.5) < 0.0001)
    }

    @Test
    func resolveExhaustsRetriesAndThrowsServerError() async throws {
        let sleeper = RecordingTaskSleeper()
        let testResolver = resolver([
            .failure(.server(statusCode: 503)),
            .failure(.server(statusCode: 503))
        ])
        let retry = ThomasViewInfo.AsyncViewController.RetryingConfig(
            maxRetries: 1,
            initialBackoff: 0.1,
            maxBackoff: 10.0
        )
        let state = ThomasAsyncViewState(
            properties: try makeProperties(retry: retry),
            resolver: testResolver,
            taskSleeper: sleeper
        )
        await #expect(throws: (any Error).self) {
            try await state.resolve()
        }
        #expect(state.response == nil)
        #expect(testResolver.callCount == 2)
        let intervals = await sleeper.sleepIntervals
        #expect(intervals.count == 2)
        #expect(intervals[0] == 0)
    }

    @Test
    func resolveWithMaxRetriesZeroPerformsSingleAttempt() async throws {
        let sleeper = RecordingTaskSleeper()
        let testResolver = resolver([.failure(.server(statusCode: 500))])
        let retry = ThomasViewInfo.AsyncViewController.RetryingConfig(
            maxRetries: 0,
            initialBackoff: 1.0,
            maxBackoff: 10.0
        )
        let state = ThomasAsyncViewState(
            properties: try makeProperties(retry: retry),
            resolver: testResolver,
            taskSleeper: sleeper
        )
        await #expect(throws: (any Error).self) {
            try await state.resolve()
        }
        #expect(testResolver.callCount == 1)
        #expect(await sleeper.sleepIntervals.count == 1)
    }

    @Test
    func resolveNilPropertiesThrows() async throws {
        let state = ThomasAsyncViewState(
            properties: nil,
            resolver: resolver([.success(validViewInfoJSONData)]),
            taskSleeper: RecordingTaskSleeper()
        )
        await #expect(throws: (any Error).self) {
            try await state.resolve()
        }
    }

    /// When prefetch is required, a failed download does not publish `response`; layout is retained for retry.
    @Test
    func resolveFailsWhenImageAssetPrefetchFailsAndKeepsPendingLayout() async throws {
        let testResolver = resolver([.success(invalidImageUrlViewInfoJSONData)])
        let imageLoader = StubThomasImageLoader(prefetchError: URLError(.cannotConnectToHost))
        let state = ThomasAsyncViewState(
            properties: try makeProperties(),
            resolver: testResolver,
            imageLoader: imageLoader,
            taskSleeper: RecordingTaskSleeper()
        )

        await #expect(throws: (any Error).self) {
            try await state.resolve()
        }
        #expect(state.response == nil)
        #expect(state.resolvedLayoutAwaitingPrefetch != nil)
        #expect(testResolver.callCount == 1)

        #expect(imageLoader.prefetchInvocations.count == 1)
        #expect(imageLoader.prefetchInvocations[0] == [":::invalid"])
    }

    @Test
    func retryAfterPrefetchFailureRetriesPrefetchWithoutSecondHTTPRequest() async throws {
        let testResolver = resolver([.success(invalidImageUrlViewInfoJSONData)])
        let imageLoader = StubThomasImageLoader(prefetchFailuresRemaining: 1)
        let state = ThomasAsyncViewState(
            properties: try makeProperties(),
            resolver: testResolver,
            imageLoader: imageLoader,
            taskSleeper: RecordingTaskSleeper()
        )

        await #expect(throws: (any Error).self) {
            try await state.resolve()
        }
        #expect(testResolver.callCount == 1)
        #expect(state.resolvedLayoutAwaitingPrefetch != nil)

        state.retry()
        for _ in 0..<400 {
            if case .loaded = state.status { break }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        #expect(state.response != nil)
        #expect(state.status == .loaded)
        #expect(state.resolvedLayoutAwaitingPrefetch == nil)
        #expect(testResolver.callCount == 1)
        #expect(imageLoader.prefetchInvocations.count == 2)
    }

    // MARK: - Async view assets

    @Test
    func resolvePrefetchInvokesCacheWithDecodedImageUrlsBeforePublishingResponse() async throws {
        let testResolver = resolver([.success(validImageUrlMediaViewInfoJSONData)])
        let imageLoader = StubThomasImageLoader()
        let state = ThomasAsyncViewState(
            properties: try makeProperties(identifier: "scene-asset-id"),
            resolver: testResolver,
            imageLoader: imageLoader,
            taskSleeper: RecordingTaskSleeper()
        )

        try await state.resolve()

        #expect(state.response != nil)
        #expect(state.resolvedLayoutAwaitingPrefetch == nil)
        #expect(imageLoader.prefetchInvocations.count == 1)
        #expect(imageLoader.prefetchInvocations[0] == ["https://cdn.example.com/async-asset.png"])
    }

    @Test
    func resolveWithNoImageUrlsDoesNotPrefetch() async throws {
        let testResolver = resolver([.success(validViewInfoJSONData)])
        let imageLoader = StubThomasImageLoader()
        let state = ThomasAsyncViewState(
            properties: try makeProperties(),
            resolver: testResolver,
            imageLoader: imageLoader,
            taskSleeper: RecordingTaskSleeper()
        )

        try await state.resolve()

        #expect(state.response != nil)
        #expect(imageLoader.prefetchInvocations.isEmpty)
    }

    @Test
    func resolveSkipsPrefetchWhenImageLoaderNotConfigured() async throws {
        let testResolver = resolver([.success(validImageUrlMediaViewInfoJSONData)])
        let state = ThomasAsyncViewState(
            properties: try makeProperties(),
            resolver: testResolver,
            taskSleeper: RecordingTaskSleeper()
        )

        try await state.resolve()

        #expect(state.response != nil)
    }

    @Test
    func resolveSucceedsWhenPrefetchReturnsNoToken() async throws {
        let testResolver = resolver([.success(validImageUrlMediaViewInfoJSONData)])
        let imageLoader = StubThomasImageLoader()
        let state = ThomasAsyncViewState(
            properties: try makeProperties(),
            resolver: testResolver,
            imageLoader: imageLoader,
            taskSleeper: RecordingTaskSleeper()
        )

        try await state.resolve()

        #expect(state.response != nil)
        #expect(imageLoader.prefetchInvocations.count == 1)
    }

    @Test
    func retryMapsAssetPrefetchFailureToImagePrefetchFailedStatus() async throws {
        let testResolver = resolver([.success(invalidImageUrlViewInfoJSONData)])
        let imageLoader = StubThomasImageLoader(prefetchError: URLError(.cannotConnectToHost))
        let state = ThomasAsyncViewState(
            properties: try makeProperties(),
            resolver: testResolver,
            imageLoader: imageLoader,
            taskSleeper: RecordingTaskSleeper()
        )

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
        let testResolver = resolver([.success(validViewInfoJSONData)])
        let state = ThomasAsyncViewState(
            properties: try makeProperties(),
            resolver: testResolver,
            taskSleeper: RecordingTaskSleeper()
        )
        state.retry()
        for _ in 0..<400 {
            if case .loaded = state.status { break }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        #expect(state.response != nil)
        #expect(state.status == .loaded)
        #expect(testResolver.callCount == 1)
    }

    @Test
    func startResolveDoesNothingAfterSuccessfulResolve() async throws {
        let testResolver = resolver([.success(invalidImageUrlViewInfoJSONData)])
        let state = ThomasAsyncViewState(
            properties: try makeProperties(),
            resolver: testResolver,
            taskSleeper: RecordingTaskSleeper()
        )
        try await state.resolve()
        #expect(testResolver.callCount == 1)
        state.retry()
        try await Task.sleep(nanoseconds: 20_000_000)
        #expect(testResolver.callCount == 1)
        #expect(state.response != nil)
    }

    @Test
    func startResolveMapsFinalServerErrorToStatus() async throws {
        let testResolver = resolver([.failure(.server(statusCode: 404))])
        let retry = ThomasViewInfo.AsyncViewController.RetryingConfig(
            maxRetries: 0,
            initialBackoff: 0.01,
            maxBackoff: 1.0
        )
        let state = ThomasAsyncViewState(
            properties: try makeProperties(retry: retry),
            resolver: testResolver,
            taskSleeper: RecordingTaskSleeper()
        )
        state.retry()
        for _ in 0..<400 {
            if case .error = state.status { break }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        #expect(state.status == .error(.server(statusCode: 404)))
    }
}
