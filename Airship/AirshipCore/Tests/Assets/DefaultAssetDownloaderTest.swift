/* Copyright Airship and Contributors */

import Testing
@_spi(AirshipInternal) import AirshipBasement
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

    @Test
    func testDownloadAssetSuccessStatusCode() async throws {
        let expectedData = Data("Cool story".utf8)
        mockSession.nextData = expectedData
        mockSession.nextResponse = HTTPURLResponse(
            url: testURL,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        let tempURL = try await downloader.downloadAsset(remoteURL: testURL)

        let downloadedData = try Data(contentsOf: tempURL)
        #expect(downloadedData == expectedData, "Downloaded data at the temp URL should match the expected data.")
    }

    @Test(arguments: [404, 503])
    func testDownloadAssetErrorStatusCodeThrows(statusCode: Int) async throws {
        mockSession.nextData = Data("<html>error page</html>".utf8)
        mockSession.nextResponse = HTTPURLResponse(
            url: testURL,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )

        let error = await #expect(throws: (any Error).self, "Error status codes should not be treated as successful downloads") {
            try await downloader.downloadAsset(remoteURL: testURL)
        }

        #expect(
            error?.localizedDescription.contains("status \(statusCode)") == true,
            "The thrown error should be the status validation error, not an unrelated failure"
        )
    }
}
