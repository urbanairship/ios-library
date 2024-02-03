/* Copyright Airship and Contributors */

import Foundation

/// Wrapper for the download tasks that is responsible for downloading assets
protocol AssetDownloader: Sendable {
    /// Downloads the asset from a remote URL and returns its temporary local URL
    func downloadAsset(remoteURL: URL) async throws -> URL
}

/// Wrapper for the filesystem that is responsible for asset-caching related file and directory operations
protocol AssetFileManager: Sendable {
    /// Gets or creates the root directory
    var rootDirectory: URL? { get }

    /// Gets or creates cache directory based on the root directory with the provided identifier (usually a schedule ID) and returns its full cache URL
    func ensureCacheDirectory(identifier: String) throws -> URL

    /// Checks if asset file or directory exists at cache URL
    func assetItemExists(at cacheURL: URL) -> Bool

    /// Moves the asset from a temporary URL to its asset cache directory
    func moveAsset(from tempURL: URL, to cacheURL: URL) throws

    /// Clears all assets corresponding to the provided identifier
    func clearAssets(identifier: String, cacheURL: URL) throws
}

protocol AssetCacheManagerProtocol: AnyActor {
    func cacheAssets(
        identifier: String,
        assets: [String]
    ) async throws -> AirshipCachedAssetsProtocol

    func clearCache(identifier: String) async
}


/// Downloads and caches asset files in filesystem using cancelable thread-safe tasks.
actor AssetCacheManager: AssetCacheManagerProtocol {
    private let assetDownloader: AssetDownloader
    private let assetFileManager: AssetFileManager

    private var cacheRoot: URL?

    private var taskMap: [String: Task<AirshipCachedAssets, Error>] = [:]

    internal init(
        assetDownloader: AssetDownloader = DefaultAssetDownloader(),
        assetFileManager: AssetFileManager = DefaultAssetFileManager()
    ) {
        self.assetDownloader = assetDownloader
        self.assetFileManager = assetFileManager

        /// Set cache root for clearing operations
        self.cacheRoot = assetFileManager.rootDirectory
    }

    /// Cache assets for a given identifer.
    /// Downloads assets from remote paths and stores them in an identifier-named cache directory with consistent and unique file names
    /// derived from their remote paths using sha256.
    /// - Parameters:
    ///   - identifier: Name of the directory within the root cache directory, usually an in-app message schedule ID
    ///   - assets: An array of remote URL paths for the assets assoicated with the provided identifer
    /// - Returns: AirshipCachesAssets instance
    func cacheAssets(
        identifier: String,
        assets: [String]
    ) async throws -> AirshipCachedAssetsProtocol {
        let task: Task<AirshipCachedAssets, Error> = Task {
            let assetURLs = assets.compactMap({ URL(string:$0) })

            /// Create or get the directory for the assets corresponding to a specific identifier
            let cacheDirectory = try assetFileManager.ensureCacheDirectory(identifier: identifier)

            let cachedAssets = AirshipCachedAssets(directory: cacheDirectory, assetFileManager: assetFileManager)

            for asset in assetURLs {                
                /// Cancellable download task
                let tempURL = try await self.assetDownloader.downloadAsset(remoteURL: asset)
    
                if Task.isCancelled {
                    return cachedAssets
                }

                if let cacheURL = cachedAssets.cachedURL(remoteURL: asset) {
                    /// Move the asset to its cache location:
                    /// <.cachesDirectory>/com.urbanairship.iamassetcache/<schedule ID>/<sha256 hashed remote URL>
                    try assetFileManager.moveAsset(from:tempURL, to:cacheURL)
                }
            }

            return cachedAssets
        }

        taskMap[identifier] = task

        return try await task.result.get()
    }


    /// Clears the cache directory associated with the identifier
    /// - Parameter identifier: Name of the directory within the root cache directory, usually an in-app message schedule ID
    func clearCache(identifier: String) async {
        taskMap[identifier]?.cancel()
        taskMap.removeValue(forKey: identifier)

        if let root = self.cacheRoot {
            let cache = root.appendingPathComponent(identifier, isDirectory: true)

            try? assetFileManager.clearAssets(identifier: identifier, cacheURL: cache)
        }
    }
}
