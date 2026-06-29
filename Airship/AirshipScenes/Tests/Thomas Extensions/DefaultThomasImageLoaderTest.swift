/* Copyright Airship and Contributors */

import Testing
import Foundation
@testable @_spi(AirshipInternal) import AirshipCore
@testable @_spi(AirshipInternal) import AirshipScenes
@_spi(AirshipInternal) import AirshipBasement

@MainActor
struct DefaultThomasImageLoaderTest {

    @Test
    func prefetchCachesAssetsAndAddsChildProvider() async throws {
        let provider = TestImageProvider()
        let assetManager = TestAssetManager()
        let loader = DefaultThomasImageLoader(
            imageProvider: provider,
            assetCacheManager: assetManager
        )

        try await loader.prefetch(urls: ["https://example.com/a.png"])

        let calls = await assetManager.cacheCalls
        #expect(calls.count == 1)
        #expect(calls.first?.assets == ["https://example.com/a.png"])
        #expect(provider.addedChildCount == 1)
    }

    @Test
    func releaseAllRemovesChildrenAndClearsCaches() async throws {
        let provider = TestImageProvider()
        let assetManager = TestAssetManager()
        let loader = DefaultThomasImageLoader(
            imageProvider: provider,
            assetCacheManager: assetManager
        )

        try await loader.prefetch(urls: ["https://example.com/a.png"])
        let token = try #require(provider.lastToken)
        let identifier = try #require(await assetManager.cacheCalls.first?.identifier)

        loader.releaseAll()

        #expect(provider.removedTokens == [token])
        // clearCache runs in a detached task; wait for it to land on the actor.
        try await waitUntil { await assetManager.clearedIdentifiers == [identifier] }
    }

    @Test
    func prefetchWithNoURLsIsNoOp() async throws {
        let provider = TestImageProvider()
        let assetManager = TestAssetManager()
        let loader = DefaultThomasImageLoader(
            imageProvider: provider,
            assetCacheManager: assetManager
        )

        try await loader.prefetch(urls: [])

        #expect(await assetManager.cacheCalls.isEmpty)
        #expect(provider.addedChildCount == 0)
    }

    @Test
    func prefetchClearsCacheWhenChildCannotBeAdded() async throws {
        let provider = TestImageProvider()
        provider.acceptsChildren = false
        let assetManager = TestAssetManager()
        let loader = DefaultThomasImageLoader(
            imageProvider: provider,
            assetCacheManager: assetManager
        )

        try await loader.prefetch(urls: ["https://example.com/a.png"])
        let identifier = try #require(await assetManager.cacheCalls.first?.identifier)

        // The asset cache was created, then immediately cleared because the child was rejected.
        #expect(await assetManager.clearedIdentifiers == [identifier])

        // Nothing was retained, so releaseAll has nothing to tear down.
        loader.releaseAll()
        #expect(provider.removedTokens.isEmpty)
    }
}

// MARK: - Test doubles

@MainActor
private final class TestImageProvider: AirshipImageProvider {
    var acceptsChildren = true
    private(set) var addedChildCount = 0
    private(set) var lastToken: String?
    private(set) var removedTokens: [String] = []
    private var nextToken = 0

    func get(url: URL) -> AirshipImageData? { nil }

    func tryAddChild(_ cache: any AirshipImageProvider) -> String? {
        guard acceptsChildren else { return nil }
        addedChildCount += 1
        nextToken += 1
        let token = "token-\(nextToken)"
        lastToken = token
        return token
    }

    func removeChild(token: String) {
        removedTokens.append(token)
    }
}

private final actor TestAssetManager: AssetCacheManagerProtocol {
    private(set) var cacheCalls: [(identifier: String, assets: [String])] = []
    private(set) var clearedIdentifiers: [String] = []

    func cacheAssets(identifier: String, assets: [String]) async throws -> any AirshipCachedAssetsProtocol {
        cacheCalls.append((identifier, assets))
        return EmptyAirshipCachedAssets()
    }

    func clearCache(identifier: String) async {
        clearedIdentifiers.append(identifier)
    }
}

/// Polls an async condition until it holds, failing after a short timeout.
private func waitUntil(
    timeout: TimeInterval = 2.0,
    _ condition: @Sendable () async -> Bool
) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while await !condition() {
        if Date() > deadline {
            Issue.record("Condition not met within \(timeout)s")
            return
        }
        try await Task.sleep(nanoseconds: 5_000_000)
    }
}
