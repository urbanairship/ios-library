/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

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
    func clearAssets(cacheURL: URL) throws
}

protocol AssetCacheManagerProtocol: Actor {
    func cacheAssets(
        identifier: String,
        assets: [String]
    ) async throws -> any AirshipCachedAssetsProtocol

    func clearCache(identifier: String) async
}


/// Downloads and caches asset files in filesystem using cancelable thread-safe tasks.
actor AssetCacheManager: AssetCacheManagerProtocol {
    private let assetDownloader: any AssetDownloader
    private let assetFileManager: any AssetFileManager

    private var cacheRoot: URL?
    private var taskMap: [String: Task<AirshipCachedAssets, any Error>] = [:]

    private let downloadSemaphore: AirshipAsyncSemaphore = AirshipAsyncSemaphore(value: 6)

    internal init(
        assetDownloader: any AssetDownloader = DefaultAssetDownloader(),
        assetFileManager: any AssetFileManager = DefaultAssetFileManager()
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
    ) async throws -> any AirshipCachedAssetsProtocol {
        
        if let running = taskMap[identifier] {
            return try await running.result.get()
        }
        
        let task: Task<AirshipCachedAssets, any Error> = Task {
            let startTime = Date()

            // Deduplicate URLs to prevent concurrent operations on the same asset
            let uniqueAssets = Array(Set(assets))
            let assetURLs = uniqueAssets.compactMap({ URL(string:$0) })

            // Log if duplicate URLs were found
            if assets.count != uniqueAssets.count {
                AirshipLogger.debug("Found duplicate asset URLs for identifier \(identifier): \(assets.count) URLs reduced to \(uniqueAssets.count) unique URLs")
            }

            /// Create or get the directory for the assets corresponding to a specific identifier
            let cacheDirectory = try assetFileManager.ensureCacheDirectory(identifier: identifier)

            let cachedAssets = AirshipCachedAssets(directory: cacheDirectory, assetFileManager: assetFileManager)

            try await withThrowingTaskGroup(of: Void.self) { [downloadSemaphore] group in
                for asset in assetURLs {
                    group.addTask {
                        try await downloadSemaphore.withPermit {
                            if Task.isCancelled || cachedAssets.isCached(remoteURL: asset) {
                                return
                            }

                            let tempURL = try await self.assetDownloader.downloadAsset(remoteURL: asset)

                            // Double-check after download in case another task cached it
                            if cachedAssets.isCached(remoteURL: asset) {
                                // Clean up temp file and return
                                try? FileManager.default.removeItem(at: tempURL)
                                AirshipLogger.trace("Asset was cached by another task during download, skipping: \(asset)")
                                return
                            }

                            if let cacheURL = cachedAssets.cachedURL(remoteURL: asset) {
                                try self.assetFileManager.moveAsset(from: tempURL, to: cacheURL)
                            }
                        }
                    }
                }

                try await group.waitForAll()
            }

            let duration = Date().timeIntervalSince(startTime)

            AirshipLogger.debug("In-app message \(identifier): \(assets.count) assets prepared in \(duration) seconds")


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

            do {
                try assetFileManager.clearAssets(cacheURL: cache)
            } catch {
                AirshipLogger.debug("Unable to clear asset cache for identifier: \(identifier) with error:\(error)")
            }
        }
    }
}


