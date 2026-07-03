/* Copyright Airship and Contributors */

public import Foundation
@_spi(AirshipInternal) import AirshipBasement

/// - NOTE: For internal use only. :nodoc:
@_spi(AirshipInternal)
public struct DefaultAssetFileManager: AssetFileManager, Sendable {

    public enum RootLocation: Sendable {
        /// Persists until the app clears caches; default for long-lived asset caches.
        case cachesDirectory
        /// Under the process temp directory; suitable for short-lived caches the OS may reclaim.
        case temporaryDirectory
    }

    private let rootPathComponent: String
    private let rootLocation: RootLocation

    private var fileManager: FileManager { FileManager.default }

    public init(
        rootPathComponent: String = "com.urbanairship.iamassetcache",
        rootLocation: RootLocation = .cachesDirectory
    ) {
        self.rootPathComponent = rootPathComponent
        self.rootLocation = rootLocation
    }

    public var rootDirectory: URL? {
        try? ensureCacheRootDirectory(rootPathComponent: rootPathComponent)
    }

    public func ensureCacheDirectory(identifier: String) throws -> URL {
        let url = try ensureCacheRootDirectory(rootPathComponent: rootPathComponent)
        let cacheDirectory = url.appendingPathComponent(identifier, isDirectory: true)
        return try ensureCacheDirectory(url: cacheDirectory)
    }

    public func assetItemExists(at cacheURL: URL) -> Bool {
        fileManager.fileExists(atPath: cacheURL.path)
    }

    public func moveAsset(from tempURL: URL, to cacheURL: URL) throws {
        do {
            let parentDir = cacheURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true, attributes: nil)

            if fileManager.fileExists(atPath: cacheURL.path) {
                _ = try fileManager.replaceItem(at: cacheURL,
                                                withItemAt: tempURL,
                                                backupItemName: nil,
                                                options: [],
                                                resultingItemURL: nil)
            } else {
                try fileManager.moveItem(at: tempURL, to: cacheURL)
            }
        } catch let error as NSError {
            // Handle the specific case where file already exists
            if error.domain == NSCocoaErrorDomain && error.code == NSFileWriteFileExistsError {
                // File already exists - this is okay, just clean up temp file
                try? fileManager.removeItem(at: tempURL)
                AirshipLogger.trace("Asset already exists at cache URL, skipping move: \(cacheURL)")
            } else {
                throw AirshipErrors.error("Error moving asset to asset cache \(error)")
            }
        }
    }

    public func clearAssets(cacheURL: URL) throws {
        guard fileManager.fileExists(atPath: cacheURL.path) else { return }
        try fileManager.removeItem(at: cacheURL)
    }

    // MARK: Helpers
    
    private func ensureCacheRootDirectory(rootPathComponent: String) throws -> URL {
        let baseURL: URL
        switch rootLocation {
        case .cachesDirectory:
            guard let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
                throw AirshipErrors.error("Error creating asset cache root directory: user caches directory unavailable.")
            }
            baseURL = cacheDirectory
        case .temporaryDirectory:
            baseURL = fileManager.temporaryDirectory
        }

        let cacheRootDirectory = baseURL.appendingPathComponent(rootPathComponent, isDirectory: true)
        return try ensureCacheDirectory(url: cacheRootDirectory)
    }

    private func ensureCacheDirectory(url: URL) throws -> URL {
        var isDirectory: ObjCBool = false
        let fileExists = fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)

        do {
            if !fileExists {
                try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
            } else if !isDirectory.boolValue {
                AirshipLogger.debug("Path:\(url) exists but is not a directory. Removing the file and creating the directory.")
                try fileManager.removeItem(at: url)
                try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
            }

            return url
        } catch {
            AirshipLogger.debug("Error creating directory at \(url): \(error)")
            throw error
        }
    }
}
