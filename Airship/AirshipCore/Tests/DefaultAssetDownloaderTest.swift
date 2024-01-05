/* Copyright Airship and Contributors */

import XCTest
import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif


final class TestAssetDownloaderSession: AssetDownloaderSession, @unchecked Sendable {
    var nextData: Data?
    var nextError: Error?
    var nextResponse: URLResponse?

    func autoResumingDataTask(with url: URL, completion: @escaping (Data?, URLResponse?, Error?) -> Void) -> AirshipCancellable {
        completion(nextData, nextResponse, nextError)

        return CancellableValueHolder<String>() { _ in }
    }
}

@testable import AirshipAutomationSwift
final class DefaultAssetDownloaderTest: XCTestCase {
    var downloader: DefaultAssetDownloader!
    var mockSession: TestAssetDownloaderSession!
    let testURL = URL(string: "https://airship.com/whatever")!

    override func setUpWithError() throws {
        try super.setUpWithError()
        mockSession = TestAssetDownloaderSession()
        downloader = DefaultAssetDownloader(session: mockSession)
    }

    func testDownloadAssetDataMatches() async throws {
        let expectedData = Data("Cool story".utf8)
        mockSession.nextData = expectedData

        let tempURL = try await downloader.downloadAsset(remoteURL: testURL)

        let downloadedData = try Data(contentsOf: tempURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: tempURL.path), "Downloaded file should exist at the temp URL")
        XCTAssertEqual(downloadedData, expectedData, "Downloaded data at the temp URL should match the expected data.")
    }

    override func tearDownWithError() throws {
        let fileManager = FileManager.default
        let tempFileURL = fileManager.temporaryDirectory.appendingPathComponent(testURL.lastPathComponent)
        if fileManager.fileExists(atPath: tempFileURL.path) {
            try fileManager.removeItem(at: tempFileURL)
        }

        downloader = nil
        mockSession = nil
        try super.tearDownWithError()
    }
}
