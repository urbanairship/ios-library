/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable
@_spi(AirshipInternal) import AirshipCore

fileprivate final class TestAssetDownloaderSession: AssetDownloaderSession, @unchecked Sendable {
    var nextData: Data?
    var nextError: Error?
    var nextResponse: URLResponse?

    func autoResumingDataTask(with url: URL, completion: @escaping (Data?, URLResponse?, Error?) -> Void) -> AirshipCancellable {
        completion(nextData, nextResponse, nextError)

        return CancellableValueHolder<String>() { _ in }
    }
}

@Suite struct DefaultAssetDownloaderTest {
    let downloader: DefaultAssetDownloader
    fileprivate let mockSession: TestAssetDownloaderSession
    let testURL = URL(string: "https://airship.com/whatever")!

    init() throws {
        let mockSession = TestAssetDownloaderSession()
        self.mockSession = mockSession
        self.downloader = DefaultAssetDownloader(session: mockSession)
    }

    @Test
    func testDownloadAssetDataMatches() async throws {
        let expectedData = Data("Cool story".utf8)
        mockSession.nextData = expectedData

        let tempURL = try await downloader.downloadAsset(remoteURL: testURL)

        let downloadedData = try Data(contentsOf: tempURL)

        #expect(FileManager.default.fileExists(atPath: tempURL.path), "Downloaded file should exist at the temp URL")
        #expect(downloadedData == expectedData, "Downloaded data at the temp URL should match the expected data.")
    }
}
