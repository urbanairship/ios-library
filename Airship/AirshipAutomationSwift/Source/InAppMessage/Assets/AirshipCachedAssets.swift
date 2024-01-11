/* Copyright Airship and Contributors */

import Foundation

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

struct AirshipCachedAssets: AirshipCachedAssetsProtocol, Equatable {
    static func == (lhs: AirshipCachedAssets, rhs: AirshipCachedAssets) -> Bool {
        lhs.directory == rhs.directory
    }

    private let directory: URL

    private let assetFileManager: AssetFileManager

    internal init(directory: URL, assetFileManager: AssetFileManager = DefaultAssetFileManager()) {
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


