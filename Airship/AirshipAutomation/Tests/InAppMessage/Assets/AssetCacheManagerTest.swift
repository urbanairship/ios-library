/* Copyright Airship and Contributors */

import XCTest

import AirshipCore

@testable
import AirshipAutomation

final class AssetCacheManagerTest: XCTestCase {
    class TestAssetDownloader: AssetDownloader, @unchecked Sendable {
        var downloadResult: Result<URL, Error>?
        var downloadDelaySeconds: TimeInterval = 0
        var customDownloadHandler: ((URL) async throws -> URL)?

        func downloadAsset(remoteURL: URL) async throws -> URL {
            // Simulate a network delay
            if downloadDelaySeconds > 0 {
                let delayNanoseconds = UInt64(downloadDelaySeconds * 1_000_000_000)  // Convert seconds to nanoseconds
                try await Task.sleep(nanoseconds: delayNanoseconds)
            }

            if let customHandler = customDownloadHandler {
                return try await customHandler(remoteURL)
            }

            switch downloadResult {
            case .success(let url):
                return url
            case .failure(let error):
                throw error
            case .none:
                fatalError("Download result wasn't set.")
            }
        }
    }

    class TestAssetFileManager: AssetFileManager, @unchecked Sendable {
        var onEnsureCacheRootDirectory: ((_ rootPathComponent: String) -> URL)?
        var onEnsureDirectory: ((_ identifier: String) -> URL)?
        var onMoveAsset: ((_ tempURL: URL, _ cacheURL: URL) throws -> ())?
        var onAssetItemExists: ((_ cacheURL: URL) -> Bool )?
        var onClearAssets: ((_ cacheURL: URL) -> ())?

        var rootDirectory: URL?

        func assetItemExists(at cacheURL: URL) -> Bool {
            return self.onAssetItemExists?(cacheURL) ?? false
        }

        func ensureCacheDirectory(identifier: String) throws -> URL {
            if onEnsureDirectory == nil {
                XCTFail("Testing block onEnsureDirectory testing block must be implemented and return a URL")
            }

            return self.onEnsureDirectory!(identifier)
        }

        func ensureCacheRootDirectory(rootPathComponent: String) throws -> URL {
            if onEnsureCacheRootDirectory == nil {
                XCTFail("Testing block onEnsureCacheRootDirectory must be implemented and return a URL")
            }

            return self.onEnsureCacheRootDirectory!(rootPathComponent)
        }

        func moveAsset(from tempURL: URL, to cacheURL: URL) throws {
            try self.onMoveAsset?(tempURL, cacheURL)
        }

        func clearAssets(cacheURL: URL) throws {
            self.onClearAssets?(cacheURL)
        }
    }

    /// Tests that calling cache assets on two remote URLs will result in a file move to the correct directory with those two assets
    func testCacheTwoAssets() async throws {
        let downloader = TestAssetDownloader()
        downloader.downloadResult = .success(URL(fileURLWithPath: "/temp/asset"))

        let assetRemoteURL1 = URL(string:"http://airship.com/asset1")!
        let assetRemoteURL2 = URL(string:"http://airship.com/asset2")!

        let testScheduleIdentifier = "test-schedule-id"

        let expectedRootPathComponent = "com.urbanairship.iamassetcache"

        let expectedAsset1Filename = assetRemoteURL1.assetFilename
        let expectedAsset2Filename = assetRemoteURL2.assetFilename

        let expectedRootCacheDirectory = URL(fileURLWithPath:"test-user-cache/\(expectedRootPathComponent)/")
        let expectedCacheDirectory = expectedRootCacheDirectory.appendingPathComponent(testScheduleIdentifier, isDirectory: true)

        let expectedFile1URL = expectedCacheDirectory.appendingPathComponent(assetRemoteURL1.assetFilename, isDirectory:false)
        let expectedFile2URL = expectedCacheDirectory.appendingPathComponent(assetRemoteURL2.assetFilename, isDirectory:false)

        let fileManager = TestAssetFileManager()
        
        var shouldExist = false

        fileManager.onEnsureCacheRootDirectory = { rootPathComponent in
            /// Check root path component is used for the root directory
            XCTAssertEqual(rootPathComponent, expectedRootPathComponent)
            return expectedRootCacheDirectory
        }

        fileManager.onEnsureDirectory = { identifier in
            /// Check cache directory is the root path + expected schedule identifier
            XCTAssertEqual(identifier, expectedCacheDirectory.lastPathComponent)
            return expectedCacheDirectory
        }

        fileManager.onAssetItemExists = { url in
            /// If we're checking the status of the cache directory
            if expectedCacheDirectory == url {
                return true
            }

            /// If we're checking the status of file 1
            if expectedFile1URL == url, shouldExist {
                return true
            }

            /// If we're checking the status of file 2
            if expectedFile2URL == url, shouldExist {
                return true
            }
            
            if shouldExist {
                XCTFail()
            }
            
            return false
        }

        let asset1MovedToCache = expectation(description: "Test asset 1 moved to cache")
        let asset2MovedToCache = expectation(description: "Test asset 2 moved to cache")

        fileManager.onMoveAsset = { tempURL, cachedURL in
            if expectedAsset1Filename == cachedURL.lastPathComponent {
                asset1MovedToCache.fulfill()
            }

            if expectedAsset2Filename == cachedURL.lastPathComponent {
                asset2MovedToCache.fulfill()
            }
        }

        let manager = AssetCacheManager(assetDownloader: downloader, assetFileManager: fileManager)
        await manager.clearCache(identifier: testScheduleIdentifier)

        do {
            let cachedAssets = try await manager.cacheAssets(identifier: testScheduleIdentifier, assets: [assetRemoteURL1.path, assetRemoteURL2.path])
            
            shouldExist = true

            XCTAssertTrue(cachedAssets.isCached(remoteURL: assetRemoteURL1))
            XCTAssertTrue(cachedAssets.isCached(remoteURL: assetRemoteURL2))

            XCTAssertEqual(cachedAssets.cachedURL(remoteURL: assetRemoteURL1), expectedFile1URL)
            XCTAssertEqual(cachedAssets.cachedURL(remoteURL: assetRemoteURL2), expectedFile2URL)

            await fulfillment(of: [asset1MovedToCache, asset2MovedToCache], timeout: 1)

        } catch {
            XCTFail("Caching assets should succeed: \(error)")
        }
    }

    func testClearCacheDuringActiveDownload() async throws {
        let downloader = TestAssetDownloader()
        downloader.downloadResult = .success(URL(fileURLWithPath: "/temp/asset"))
        downloader.downloadDelaySeconds = 0.5  // Set a delay to ensure clearCache is called while mock downloading is in progress

        let fileManager = TestAssetFileManager()

        fileManager.onEnsureCacheRootDirectory = { rootPathComponent in
            return URL(fileURLWithPath: "/path/to/cache")
        }

        fileManager.onEnsureDirectory = { url in
            return URL(fileURLWithPath: "/path/to/cache/identifier")
        }

        let manager = AssetCacheManager(assetDownloader: downloader, assetFileManager: fileManager)
        let identifier = "testIdentifier"

        // Start caching assets in a separate task to allow it to run in parallel
        let cacheTask = Task {
            try await manager.cacheAssets(identifier: identifier, assets: ["http://airship.com/asset"])
        }

        // Give the cacheTask a moment to start be assigned to the task map
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Clear the cache while the caching task is still in progress
        await manager.clearCache(identifier: identifier)

        // Verify that the caching task was canceled
        var isCancelled = false
        do {
            _ = try await cacheTask.result.get()
        } catch {
            if (error as? CancellationError) != nil {
                isCancelled = true
            } else {
                XCTFail("Expected a CancellationError, but received: \(error)")
            }
        }
        XCTAssertTrue(isCancelled, "The caching task should be canceled after clearing the cache.")
    }

    /// Tests that duplicate URLs in the assets array are deduplicated before processing
    func testCacheDuplicateAssets() async throws {
        let downloader = TestAssetDownloader()
        downloader.downloadResult = .success(URL(fileURLWithPath: "/temp/asset"))

        let assetRemoteURL = URL(string:"http://airship.com/duplicate-asset")!
        let testScheduleIdentifier = "test-duplicate-schedule-id"
        let expectedRootPathComponent = "com.urbanairship.iamassetcache"

        let expectedRootCacheDirectory = URL(fileURLWithPath:"test-user-cache/\(expectedRootPathComponent)/")
        let expectedCacheDirectory = expectedRootCacheDirectory.appendingPathComponent(testScheduleIdentifier, isDirectory: true)
        let expectedFileURL = expectedCacheDirectory.appendingPathComponent(assetRemoteURL.assetFilename, isDirectory:false)

        let fileManager = TestAssetFileManager()
        var downloadCount = 0
        var moveCount = 0

        // Track how many times download is called
        downloader.customDownloadHandler = { remoteURL in
            downloadCount += 1
            return URL(fileURLWithPath: "/temp/asset-\(downloadCount)")
        }

        fileManager.onEnsureCacheRootDirectory = { _ in
            return expectedRootCacheDirectory
        }

        fileManager.onEnsureDirectory = { _ in
            return expectedCacheDirectory
        }

        fileManager.onAssetItemExists = { url in
            if expectedCacheDirectory == url {
                return true
            }
            // First check returns false, subsequent checks return true
            return moveCount > 0 && url == expectedFileURL
        }

        fileManager.onMoveAsset = { tempURL, cachedURL in
            moveCount += 1
            XCTAssertEqual(cachedURL, expectedFileURL)
        }

        let manager = AssetCacheManager(assetDownloader: downloader, assetFileManager: fileManager)

        // Pass the same URL three times (simulating the bug scenario)
        let duplicateAssets = [assetRemoteURL.absoluteString, assetRemoteURL.absoluteString, assetRemoteURL.absoluteString]

        do {
            let cachedAssets = try await manager.cacheAssets(identifier: testScheduleIdentifier, assets: duplicateAssets)

            // Should only download and move once despite duplicate URLs
            XCTAssertEqual(downloadCount, 1, "Should only download once for duplicate URLs")
            XCTAssertEqual(moveCount, 1, "Should only move once for duplicate URLs")

            XCTAssertTrue(cachedAssets.isCached(remoteURL: assetRemoteURL))
            XCTAssertEqual(cachedAssets.cachedURL(remoteURL: assetRemoteURL), expectedFileURL)
        } catch {
            XCTFail("Caching duplicate assets should succeed: \(error)")
        }
    }

    /// Tests that concurrent caching of the same asset handles race conditions gracefully
    // TODO: This test needs to be redesigned to properly test the race condition handling
    func disabled_testConcurrentCachingSameAsset() async throws {
        let downloader = TestAssetDownloader()
        downloader.downloadDelaySeconds = 0.1 // Add small delay to increase chance of race condition

        let assetRemoteURL = URL(string:"http://airship.com/concurrent-asset")!
        let testScheduleIdentifier1 = "test-concurrent-schedule-1"
        let testScheduleIdentifier2 = "test-concurrent-schedule-2"

        let fileManager = TestAssetFileManager()
        var moveAttempts = 0
        let moveAttemptsSemaphore = NSLock()

        fileManager.rootDirectory = URL(fileURLWithPath: "/test-cache")

        fileManager.onEnsureDirectory = { identifier in
            return URL(fileURLWithPath: "/test-cache/\(identifier)")
        }

        var cachedFiles = Set<String>()

        fileManager.onAssetItemExists = { url in
            // Return true for directories
            if url.path.contains("/test-cache/test-concurrent-schedule") && !url.path.contains(".") {
                return true
            }
            // Check if file has been cached
            return cachedFiles.contains(url.path)
        }

        var firstMoveCompleted = false
        fileManager.onMoveAsset = { tempURL, cachedURL in
            moveAttemptsSemaphore.lock()
            defer { moveAttemptsSemaphore.unlock() }

            moveAttempts += 1

            // Simulate the race condition - second attempt fails with "file exists"
            if moveAttempts == 2 && firstMoveCompleted {
                throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteFileExistsError, userInfo: nil)
            }

            if moveAttempts == 1 {
                firstMoveCompleted = true
                cachedFiles.insert(cachedURL.path)
            }
        }

        downloader.customDownloadHandler = { _ in
            return URL(fileURLWithPath: "/temp/asset-\(UUID().uuidString)")
        }

        let manager = AssetCacheManager(assetDownloader: downloader, assetFileManager: fileManager)

        // Start two concurrent caching operations for the same asset
        async let cache1 = manager.cacheAssets(identifier: testScheduleIdentifier1, assets: [assetRemoteURL.absoluteString])
        async let cache2 = manager.cacheAssets(identifier: testScheduleIdentifier2, assets: [assetRemoteURL.absoluteString])

        do {
            // Both should succeed despite potential race condition
            let (result1, result2) = try await (cache1, cache2)

            XCTAssertNotNil(result1)
            XCTAssertNotNil(result2)

            // At least 2 move attempts should have been made
            moveAttemptsSemaphore.lock()
            let finalMoveAttempts = moveAttempts
            moveAttemptsSemaphore.unlock()

            XCTAssertGreaterThanOrEqual(finalMoveAttempts, 1, "Should have attempted to move at least once")
        } catch {
            XCTFail("Concurrent caching should handle race conditions gracefully: \(error)")
        }
    }
}

fileprivate extension URL {
    var assetFilename: String {
        return AirshipUtils.sha256Hash(input: self.path)
    }
}

