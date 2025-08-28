/* Copyright Airship and Contributors */



#if canImport(AirshipCore)
import AirshipCore
#endif

 /// Convenience struct representing an assets directory containing asset files
 /// with filenames derived from their remote URL using sha256.
public protocol AirshipCachedAssetsProtocol: Sendable {
    /// Return URL at which to cache a given asset
    /// - Parameters:
    ///     - remoteURL: URL from which the cached data is fetched
    /// - Returns: URL at which to cache a given asset
    func cachedURL(remoteURL: URL) -> URL?

    /// Checks if a URL is cached
    /// - Parameters:
    ///     - remoteURL: URL from which the cached data is fetched
    /// - Returns: true if cached, otherwise false.
    func isCached(remoteURL: URL) -> Bool
}

struct EmptyAirshipCachedAssets: AirshipCachedAssetsProtocol {
    func cachedURL(remoteURL: URL) -> URL? {
        return nil
    }
    
    func isCached(remoteURL: URL) -> Bool {
        return false
    }
}

struct AirshipCachedAssets: AirshipCachedAssetsProtocol, Equatable {
    static func == (lhs: AirshipCachedAssets, rhs: AirshipCachedAssets) -> Bool {
        lhs.directory == rhs.directory
    }

    private let directory: URL

    private let assetFileManager: any AssetFileManager

    internal init(directory: URL, assetFileManager: any AssetFileManager = DefaultAssetFileManager()) {
        self.directory = directory
        self.assetFileManager = assetFileManager
    }

    private func getCachedAsset(from remoteURL: URL) -> URL {
        /// Derive a unique and consistent asset filename from the remote URL using sha256
        let filename: String = remoteURL.assetFilename

        return directory.appendingPathComponent(filename, isDirectory: false)
    }

    func cachedURL(remoteURL: URL) -> URL? {
        let cached: URL = getCachedAsset(from: remoteURL)

        /// Ensure directory exists
        guard assetFileManager.assetItemExists(at: directory) else {
            return nil
        }

        return cached
    }

    func isCached(remoteURL: URL) -> Bool {
        let cached: URL = getCachedAsset(from: remoteURL)

        return assetFileManager.assetItemExists(at: cached)
    }
}


fileprivate extension URL {
    var assetFilename: String {
        return AirshipUtils.sha256Hash(input: self.path)
    }
}
