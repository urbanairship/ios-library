/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Data task wrapper used for testing the default asset downloader
protocol AssetDownloaderSession: Sendable {
    func autoResumingDataTask(with url: URL, completion: @escaping (Data?, URLResponse?, Error?) -> Void) -> AirshipCancellable
}

extension URLSession: AssetDownloaderSession {
    func autoResumingDataTask(with url: URL, completion: @escaping (Data?, URLResponse?, Error?) -> Void) -> AirshipCancellable {
        
        let task = self.dataTask(with: url, completionHandler: { data, response, error in
            completion(data, response, error)
        })

        task.resume()

        return CancellableValueHolder(value: task) { task in
            task.cancel()
        }
    }
}

struct DefaultAssetDownloader : AssetDownloader {
    var session: AssetDownloaderSession

    init(session: AssetDownloaderSession = URLSession.airshipSecureSession) {
        self.session = session
    }

    func downloadAsset(remoteURL: URL) async throws -> URL {
        let cancellable = CancellableValueHolder<AirshipCancellable>() { cancellable in
            cancellable.cancel()
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                cancellable.value = session.autoResumingDataTask(with: remoteURL) { data, response, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let data = data else {
                        continuation.resume(throwing: URLError(.badServerResponse))
                        return
                    }

                    do {
                        let tempDirectory = FileManager.default.temporaryDirectory
                        let tempFileURL = tempDirectory.appendingPathComponent(remoteURL.lastPathComponent)
                        try data.write(to: tempFileURL)
                        continuation.resume(returning: tempFileURL)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        } onCancel: {
            cancellable.cancel()
        }
    }
}
