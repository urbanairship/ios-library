/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Data task wrapper used for testing the default asset downloader
protocol AssetDownloaderSession: Sendable {
    func autoResumingDataTask(with url: URL, completion: @Sendable @escaping (Data?, URLResponse?, (any Error)?) -> Void) -> any AirshipCancellable
}

extension URLSession: AssetDownloaderSession {
    func autoResumingDataTask(with url: URL, completion: @Sendable @escaping (Data?, URLResponse?, (any Error)?) -> Void) -> any AirshipCancellable {
        
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
    var session: any AssetDownloaderSession

    init(session: any AssetDownloaderSession = URLSession.airshipSecureSession) {
        self.session = session
    }

    func downloadAsset(remoteURL: URL) async throws -> URL {
        let cancellable = CancellableValueHolder<any AirshipCancellable>() { cancellable in
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
                        let tempFileURL = tempDirectory.appendingPathComponent(UUID().uuidString + remoteURL.lastPathComponent)
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
