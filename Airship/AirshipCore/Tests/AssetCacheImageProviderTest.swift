/* Copyright Airship and Contributors */

import Foundation
import Testing

@testable
@_spi(AirshipInternal) import AirshipBasement
@_spi(AirshipInternal) import AirshipCore

// MARK: - Utils

private struct TestCachedAssets: AirshipCachedAssetsProtocol, Sendable {
    let fileURLForRemote: @Sendable (URL) -> URL?

    func cachedURL(remoteURL: URL) -> URL? {
        fileURLForRemote(remoteURL)
    }

    func isCached(remoteURL: URL) -> Bool {
        cachedURL(remoteURL: remoteURL) != nil
    }
}

private func imageData(
    from assets: TestCachedAssets,
    remoteURL: URL
) -> AirshipImageData? {
    guard
        let cached = assets.cachedURL(remoteURL: remoteURL),
        let data = FileManager.default.contents(atPath: cached.path),
        let imageData = try? AirshipImageData(data: data)
    else {
        return nil
    }
    return imageData
}

@MainActor
private final class TrackingImageProvider: AirshipImageProvider {
    private(set) var getInvocationCount = 0

    var imageToReturn: AirshipImageData?

    func get(url: URL) -> AirshipImageData? {
        getInvocationCount += 1
        return imageToReturn
    }

    func tryAddChild(_ cache: any AirshipImageProvider) -> String? { nil }

    func removeChild(token: String) {}
}

// MARK: - Tests

@Suite("ExtendableAssetCacheImageProvider", .serialized)
@MainActor
struct AssetCacheImageProviderTest {

    /// 1×1 transparent PNG (valid for `AirshipImageData`).
    private var tinyPNGData: Data {
        Data(
            base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg=="
        )!
    }

    private func tempPNGFile() throws -> (remote: URL, file: URL) {
        let remote = URL(string: "https://cdn.example.com/asset.png")!
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("AirshipAssetCacheTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("cached.bin")
        try tinyPNGData.write(to: file)
        return (remote, file)
    }

    @Test
    func rootAssetsAreConsultedBeforeChildren() throws {
        let (remote, file) = try tempPNGFile()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }

        let rootAssets = TestCachedAssets { _ in file }
        let tracker = TrackingImageProvider()
        tracker.imageToReturn = try AirshipImageData(data: tinyPNGData)

        let parent = ExtendableAssetCacheImageProvider(parent: { url in
            imageData(from: rootAssets, remoteURL: url)
        })
        _ = parent.tryAddChild(tracker)

        let result = parent.get(url: remote)
        #expect(result != nil)
        #expect(tracker.getInvocationCount == 0)
    }

    @Test
    func childUsedWhenRootMisses() throws {
        let (remote, file) = try tempPNGFile()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }

        let rootMiss = TestCachedAssets { _ in nil }
        let leafAssets = TestCachedAssets { _ in file }
        let leaf = NonExtendableAssetCacheImageProvider { url in
            imageData(from: leafAssets, remoteURL: url)
        }

        let parent = ExtendableAssetCacheImageProvider(parent: { url in
            imageData(from: rootMiss, remoteURL: url)
        })
        _ = parent.tryAddChild(leaf)

        let result = parent.get(url: remote)
        #expect(result != nil)
    }

    @Test
    func tryAddChildReturnsIdentifier() {
        let parent = ExtendableAssetCacheImageProvider(parent: nil)
        let leaf = NonExtendableAssetCacheImageProvider { _ in nil }
        let id = parent.tryAddChild(leaf)
        #expect(id != nil)
    }

    @Test
    func removeChildPreventsFurtherLookup() throws {
        let (remote, file) = try tempPNGFile()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }

        let rootMiss = TestCachedAssets { _ in nil }
        let leafAssets = TestCachedAssets { _ in file }
        let leaf = NonExtendableAssetCacheImageProvider { url in
            imageData(from: leafAssets, remoteURL: url)
        }

        let parent = ExtendableAssetCacheImageProvider(parent: { url in
            imageData(from: rootMiss, remoteURL: url)
        })
        let id = try #require(parent.tryAddChild(leaf))
        #expect(parent.get(url: remote) != nil)

        parent.removeChild(token: id)
        #expect(parent.get(url: remote) == nil)
    }

    @Test
    func nonExtendableRejectsTryAddChild() {
        let leaf = NonExtendableAssetCacheImageProvider { _ in nil }
        let dummy = ExtendableAssetCacheImageProvider(parent: nil)
        #expect(leaf.tryAddChild(dummy) == nil)
    }

    @Test
    func nonExtendableLoadsFromDisk() throws {
        let (remote, file) = try tempPNGFile()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }

        let assets = TestCachedAssets { _ in file }
        let leaf = NonExtendableAssetCacheImageProvider { url in
            imageData(from: assets, remoteURL: url)
        }
        let result = leaf.get(url: remote)
        #expect(result != nil)
    }
}
