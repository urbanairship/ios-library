/* Copyright Airship and Contributors */

@_spi(AirshipInternal) import AirshipSceneRenderer
@_spi(AirshipInternal) import AirshipCore
import Foundation

/// The image loader the SDK wires up by default — loads via the SDK's image loader and prefetches
/// into an asset cache. Owns the lifecycle of everything it prefetches, releasing it all in
/// `releaseAll()` (the environment calls this on dismiss).
@MainActor
final class DefaultThomasImageLoader: ThomasImageLoader {
    private static let assetCacheRootComponent: String = "com.airship.layout.assets"

    private let imageProvider: (any AirshipImageProvider)?
    private let imageLoader: AirshipImageLoader
    private let assetCacheManager: any AssetCacheManagerProtocol

    /// Maps a child-provider token to the asset-cache identifier backing it, so `releaseAll()` can
    /// tear down both.
    private var prefetchCacheIdentifiers: [String: String] = [:]

    init(
        imageProvider: (any AirshipImageProvider)? = nil,
        assetCacheManager: (any AssetCacheManagerProtocol)? = nil
    ) {
        self.imageProvider = imageProvider
        self.imageLoader = AirshipImageLoader(
            imageProvider: imageProvider,
            session: URLSession.airshipSecureSession
        )
        self.assetCacheManager = assetCacheManager ?? Self.makeAssetCacheManager()
    }

    private static func makeAssetCacheManager() -> any AssetCacheManagerProtocol {
        AssetCacheManager(
            assetFileManager: DefaultAssetFileManager(
                rootPathComponent: assetCacheRootComponent,
                rootLocation: .temporaryDirectory
            )
        )
    }

    func load(url: String) async throws -> AirshipImageData {
        try await imageLoader.load(url: url)
    }

    func prefetch(urls: [String]) async throws {
        guard let imageProvider, !urls.isEmpty else { return }

        let identifier = UUID().uuidString
        let cachedAssets = try await assetCacheManager.cacheAssets(
            identifier: identifier,
            assets: urls
        )

        let child = NonExtendableAssetCacheImageProvider { url in
            guard
                let url = cachedAssets.cachedURL(remoteURL: url),
                let data = FileManager.default.contents(atPath: url.path),
                let imageData = try? AirshipImageData(data: data)
            else {
                return nil
            }
            return imageData
        }

        guard let token = imageProvider.tryAddChild(child) else {
            await assetCacheManager.clearCache(identifier: identifier)
            return
        }

        prefetchCacheIdentifiers[token] = identifier
    }

    func releaseAll() {
        let outstanding = prefetchCacheIdentifiers
        prefetchCacheIdentifiers.removeAll()
        for (token, identifier) in outstanding {
            imageProvider?.removeChild(token: token)
            Task { await assetCacheManager.clearCache(identifier: identifier) }
        }
    }
}
