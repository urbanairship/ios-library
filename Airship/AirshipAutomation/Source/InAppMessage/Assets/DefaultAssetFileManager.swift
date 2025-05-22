/* Copyright Airship and Contributors */

import Foundation
#if canImport(AirshipCore)
import AirshipCore
#endif

struct DefaultAssetFileManager: AssetFileManager {
    private let rootPathComponent: String

    init(rootPathComponent: String = "com.urbanairship.iamassetcache") {
        self.rootPathComponent = rootPathComponent
    }

    var rootDirectory: URL? {
       try? ensureCacheRootDirectory(rootPathComponent: rootPathComponent)
    }

    func ensureCacheDirectory(identifier: String) throws -> URL {
        let url = try ensureCacheRootDirectory(rootPathComponent: rootPathComponent)

        let cacheDirectory = url.appendingPathComponent(identifier, isDirectory: true)

        return try ensureCacheDirectory(url: cacheDirectory)
    }

    func assetItemExists(at cacheURL: URL) -> Bool {
        return FileManager.default.fileExists(atPath: cacheURL.path)
    }

    func moveAsset(from tempURL: URL, to cacheURL: URL) throws {
        let fileManager = FileManager.default

        do {
            if fileManager.fileExists(atPath: cacheURL.path) {
                try fileManager.removeItem(at: cacheURL)
            }
            try fileManager.moveItem(atPath: tempURL.path, toPath: cacheURL.path)
        } catch {
            throw AirshipErrors.error("Error moving asset to asset cache \(error)")
        }
    }

    func clearAssets(cacheURL: URL) throws {
        let fileManager = FileManager.default
        try fileManager.removeItem(at: cacheURL)
    }

    // MARK: Helpers

    private func ensureCacheRootDirectory(rootPathComponent: String) throws -> URL {
        let fileManager = FileManager.default

        guard let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            throw AirshipErrors.error("Error creating asset cache root directory: user caches directory unavailable.")
        }

        fileManager.urls(for: .cachesDirectory, in: .userDomainMask)

        let cacheRootDirectory = cacheDirectory.appendingPathComponent(rootPathComponent, isDirectory: true)

        return try ensureCacheDirectory(url: cacheRootDirectory)
    }

    private func ensureCacheDirectory(url:URL) throws -> URL {
        let fileManager = FileManager.default

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
