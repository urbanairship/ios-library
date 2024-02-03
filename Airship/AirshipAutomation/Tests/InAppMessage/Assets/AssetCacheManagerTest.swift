/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipAutomation

final class AssetCacheManagerTest: XCTestCase {
    class TestAssetDownloader: AssetDownloader, @unchecked Sendable {
        var downloadResult: Result<URL, Error>?
        var downloadDelaySeconds: TimeInterval = 0

        func downloadAsset(remoteURL: URL) async throws -> URL {
            // Simulate a network delay
            if downloadDelaySeconds > 0 {
                let delayNanoseconds = UInt64(downloadDelaySeconds * 1_000_000_000)  // Convert seconds to nanoseconds
                try await Task.sleep(nanoseconds: delayNanoseconds)
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
        var onMoveAsset: ((_ tempURL: URL, _ cacheURL: URL) -> ())?
        var onAssetItemExists: ((_ cacheURL: URL) -> Bool )?
        var onClearAssets: ((_ identifier: String, _ cacheURL: URL) -> ())?

        var rootDirectory: URL?

        func assetItemExists(at cacheURL: URL) -> Bool {
            if onAssetItemExists == nil {
                XCTFail("Testing block onAssetItemExists must be implemented and return a URL")
            }

            return self.onAssetItemExists!(cacheURL)
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
            self.onMoveAsset?(tempURL, cacheURL)
        }

        func clearAssets(identifier: String, cacheURL: URL) throws {
            self.onClearAssets?(identifier, cacheURL)
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
            if expectedFile1URL == url {
                return true
            }

            /// If we're checking the status of file 2
            if expectedFile2URL == url {
                return true
            }

            XCTFail()
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

        do {
            let cachedAssets = try await manager.cacheAssets(identifier: testScheduleIdentifier, assets: [assetRemoteURL1.path, assetRemoteURL2.path])

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
}
