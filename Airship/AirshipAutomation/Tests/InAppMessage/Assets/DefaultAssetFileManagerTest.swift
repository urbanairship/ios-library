/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipAutomation
final class DefaultAssetFileManagerTest: XCTestCase {
    func testEnsureCacheRootDirectory() {
        let rootPathComponent = "testCacheRoot"
        let assetManager = DefaultAssetFileManager(rootPathComponent: rootPathComponent)
        let fileManager = FileManager.default
        let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let expectedCacheRootDirectory = cacheDirectory.appendingPathComponent(rootPathComponent, isDirectory: true)

        /// Ensure the initial state is clean
        try? fileManager.removeItem(at: expectedCacheRootDirectory)

        /// Test when nothing is there
        XCTAssertEqual(assetManager.rootDirectory, expectedCacheRootDirectory, "The method did not return the expected URL when the directory was not present initially.")

        /// Remove root and create a file in its place
        try? fileManager.removeItem(at: expectedCacheRootDirectory)
        fileManager.createFile(atPath: expectedCacheRootDirectory.path, contents: Data("TestData".utf8), attributes: nil)

        /// Test when a file is in the directory
        XCTAssertEqual(assetManager.rootDirectory, expectedCacheRootDirectory, "The method did not return the expected URL when a file was present at the directory location.")
        var isDir: ObjCBool = false
        XCTAssertTrue(fileManager.fileExists(atPath: expectedCacheRootDirectory.path, isDirectory: &isDir) && isDir.boolValue, "A directory was not created in place of the file.")
    }

    func testEnsureCacheDirectory() {
        let rootPathComponent = "testCacheRoot"
        let testIdentifier = "testIdentifier"
        let assetManager = DefaultAssetFileManager(rootPathComponent: rootPathComponent)

        let fileManager = FileManager.default
        let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let expectedCacheRootDirectory = cacheDirectory.appendingPathComponent(rootPathComponent, isDirectory: true)
        let expectedCacheDirectory = expectedCacheRootDirectory.appendingPathComponent(testIdentifier, isDirectory: true)

        XCTAssertEqual(try? assetManager.ensureCacheDirectory(identifier: testIdentifier), expectedCacheDirectory)
    }

    func testClearAssetsSuccess() {
        let rootPathComponent = "testCacheRoot"
        let assetManager = DefaultAssetFileManager(rootPathComponent: rootPathComponent)
        let cacheURL = FileManager.default.temporaryDirectory.appendingPathComponent("testAssets")
        let identifier = "testIdentifier"

        let assetsPath = cacheURL.appendingPathComponent(identifier)
        try? FileManager.default.createDirectory(at: assetsPath, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: assetsPath.appendingPathComponent("file1").path, contents: Data(), attributes: nil)

        assetManager.clearAssets(identifier: identifier, cacheURL: cacheURL)

        let directoryExists: Bool = FileManager.default.fileExists(atPath: assetsPath.path)
        XCTAssertFalse(directoryExists, "Not all assets were cleared for the identifier.")

        /// Cleanup
        try? FileManager.default.removeItem(at: cacheURL)
    }

    func testMoveAssetSuccess() {
        let rootPathComponent = "testCacheRoot"
        let assetManager = DefaultAssetFileManager(rootPathComponent: rootPathComponent)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("tempFile")
        let cacheURL = FileManager.default.temporaryDirectory.appendingPathComponent("cacheFile")

        FileManager.default.createFile(atPath: tempURL.path, contents: Data("TestData".utf8), attributes: nil)

        do {
            try assetManager.moveAsset(from: tempURL, to: cacheURL)
            XCTAssertTrue(FileManager.default.fileExists(atPath: cacheURL.path), "The file was not successfully moved to the cache URL.")
            XCTAssertFalse(FileManager.default.fileExists(atPath: tempURL.path), "The temp was not successfully cleaned up after being moved to the cache URL.")
        } catch {
            XCTFail("Failed to move asset: \(error)")
        }

        /// Cleanup
        try? FileManager.default.removeItem(at: tempURL)
        try? FileManager.default.removeItem(at: cacheURL)
    }
}
