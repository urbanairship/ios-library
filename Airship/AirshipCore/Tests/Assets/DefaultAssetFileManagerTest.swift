/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable
@_spi(AirshipInternal) import AirshipCore

@Suite struct DefaultAssetFileManagerTest {
    @Test
    func testEnsureCacheRootDirectory() {
        let rootPathComponent = "testCacheRoot"
        let assetManager = DefaultAssetFileManager(rootPathComponent: rootPathComponent)
        let fileManager = FileManager.default
        let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let expectedCacheRootDirectory = cacheDirectory.appendingPathComponent(rootPathComponent, isDirectory: true)

        /// Ensure the initial state is clean
        try? fileManager.removeItem(at: expectedCacheRootDirectory)

        /// Test when nothing is there
        #expect(assetManager.rootDirectory == expectedCacheRootDirectory, "The method did not return the expected URL when the directory was not present initially.")

        /// Remove root and create a file in its place
        try? fileManager.removeItem(at: expectedCacheRootDirectory)
        fileManager.createFile(atPath: expectedCacheRootDirectory.path, contents: Data("TestData".utf8), attributes: nil)

        /// Test when a file is in the directory
        #expect(assetManager.rootDirectory == expectedCacheRootDirectory, "The method did not return the expected URL when a file was present at the directory location.")
        var isDir: ObjCBool = false
        #expect(fileManager.fileExists(atPath: expectedCacheRootDirectory.path, isDirectory: &isDir) && isDir.boolValue, "A directory was not created in place of the file.")
    }

    @Test
    func testEnsureCacheDirectory() {
        let rootPathComponent = "testCacheRoot"
        let testIdentifier = "testIdentifier"
        let assetManager = DefaultAssetFileManager(rootPathComponent: rootPathComponent)

        let fileManager = FileManager.default
        let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let expectedCacheRootDirectory = cacheDirectory.appendingPathComponent(rootPathComponent, isDirectory: true)
        let expectedCacheDirectory = expectedCacheRootDirectory.appendingPathComponent(testIdentifier, isDirectory: true)

        #expect((try? assetManager.ensureCacheDirectory(identifier: testIdentifier)) == expectedCacheDirectory)
    }

    @Test
    func testClearAssetsSuccess() throws {
        let rootPathComponent = "testCacheRoot"
        let assetManager = DefaultAssetFileManager(rootPathComponent: rootPathComponent)
        let cacheURL = FileManager.default.temporaryDirectory.appendingPathComponent("testAssets")
        let identifier = "testIdentifier"

        let assetsPath = cacheURL.appendingPathComponent(identifier)
        try? FileManager.default.createDirectory(at: assetsPath, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: assetsPath.appendingPathComponent("file1").path, contents: Data(), attributes: nil)

        try assetManager.clearAssets(cacheURL: cacheURL)

        let directoryExists: Bool = FileManager.default.fileExists(atPath: assetsPath.path)
        #expect(!(directoryExists), "Not all assets were cleared for the identifier.")

        /// Cleanup
        try? FileManager.default.removeItem(at: cacheURL)
    }

    @Test
    func testMoveAssetSuccess() {
        let rootPathComponent = "testCacheRoot"
        let assetManager = DefaultAssetFileManager(rootPathComponent: rootPathComponent)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("tempFile")
        let cacheURL = FileManager.default.temporaryDirectory.appendingPathComponent("cacheFile")

        FileManager.default.createFile(atPath: tempURL.path, contents: Data("TestData".utf8), attributes: nil)

        do {
            try assetManager.moveAsset(from: tempURL, to: cacheURL)
            #expect(FileManager.default.fileExists(atPath: cacheURL.path), "The file was not successfully moved to the cache URL.")
            #expect(!(FileManager.default.fileExists(atPath: tempURL.path)), "The temp was not successfully cleaned up after being moved to the cache URL.")
        } catch {
            Issue.record("Failed to move asset: \(error)")
        }

        /// Cleanup
        try? FileManager.default.removeItem(at: tempURL)
        try? FileManager.default.removeItem(at: cacheURL)
    }
}
