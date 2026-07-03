/* Copyright Airship and Contributors */

public import Foundation
@_spi(AirshipInternal) import AirshipBasement

/// - NOTE: For internal use only. :nodoc:
/// Data task wrapper used for testing the default asset downloader
@_spi(AirshipInternal)
public protocol AssetDownloaderSession: Sendable {
    func autoResumingDataTask(with url: URL, completion: @Sendable @escaping (Data?, URLResponse?, (any Error)?) -> Void) -> any AirshipCancellable
}

/// - NOTE: For internal use only. :nodoc:
@_spi(AirshipInternal)
extension URLSession: AssetDownloaderSession {
    public func autoResumingDataTask(with url: URL, completion: @Sendable @escaping (Data?, URLResponse?, (any Error)?) -> Void) -> any AirshipCancellable {
        let task = self.dataTask(with: url, completionHandler: { data, response, error in
            completion(data, response, error)
        })
        task.resume()
        return CancellableValueHolder(value: task) { task in
            task.cancel()
        }
    }
}

/// - NOTE: For internal use only. :nodoc:
@_spi(AirshipInternal)
public struct DefaultAssetDownloader: AssetDownloader, Sendable {
    public var session: any AssetDownloaderSession

    public init(session: any AssetDownloaderSession = URLSession.airshipSecureSession) {
        self.session = session
    }

    public func downloadAsset(remoteURL: URL) async throws -> URL {
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
