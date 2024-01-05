/* Copyright Airship and Contributors */

import Foundation

/**
 * Convenience struct representing an assets directory containing asset files
 * with filenames derived from their remote URL using sha256
 */
public struct AirshipCachedAssets: Sendable {
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

    /**
     * Return URL at which to cache a given asset
     *
     * @param remoteURL URL from which the cached data is fetched
     * @return URL for the cached asset or `nil` if the asset cannot be cached at this time
     */
    func cachedURL(remoteURL: URL) -> URL? {
        let cached: URL = getCachedAsset(from: remoteURL)

        /// Ensure directory exists
        guard assetFileManager.assetItemExists(at: directory) else {
            return nil
        }

        return cached
    }

    /**
     * Check if file associate with the remote URL is cached
     *
     * @param remoteURL URL from which the data is fetched
     * @return `YES` if data for the URL is in the cache, `NO` if it is not.
     */
    func isCached(remoteURL: URL) -> Bool {
        let cached: URL = getCachedAsset(from: remoteURL)

        return assetFileManager.assetItemExists(at: cached)
    }
}


