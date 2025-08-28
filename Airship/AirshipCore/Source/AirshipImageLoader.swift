/* Copyright Airship and Contributors */

import Combine
import SwiftUI

public struct AirshipImageLoader {
    private static let retryDelay = 10
    private static let retries = 10

    private let imageProvider: (any AirshipImageProvider)?

    public init(imageProvider: (any AirshipImageProvider)? = nil) {
        self.imageProvider = imageProvider
    }

    func load(url: String) -> AnyPublisher<AirshipImageData, any Error> {
        guard let url = URL(string: url) else {
            return Fail(error: AirshipErrors.error("Invalid URL"))
                .eraseToAnyPublisher()
        }

        return Deferred { () -> AnyPublisher<AirshipImageData, any Error> in
            // First, check the image provider (cache)
            if let imageData = self.imageProvider?.get(url: url) {
                return Just(imageData)
                    .setFailureType(to: (any Error).self)
                    .eraseToAnyPublisher()
            }

            // If not cached, check if it's a local file URL
            if url.isFileURL {
                return self.loadImageFromFile(url: url)
            } else {
                // Otherwise, fetch from the network
                return self.fetchImage(url: url)
            }
        }
        .subscribe(on: DispatchQueue.global(qos: .userInteractive))
        .eraseToAnyPublisher()
    }

    private func loadImageFromFile(url: URL) -> AnyPublisher<AirshipImageData, any Error> {
        do {
            let data = try Data(contentsOf: url)
            let imageData = try AirshipImageData(data: data)
            return Just(imageData)
                .setFailureType(to: (any Error).self)
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: AirshipErrors.error("failed to fetch message"))
                .eraseToAnyPublisher()
        }
    }

    private func fetchImage(url: URL) -> AnyPublisher<AirshipImageData, any Error> {
        return URLSession.airshipSecureSession.dataTaskPublisher(for: url)
            .mapError { AirshipErrors.error("URL error \($0)") }
            .map { response -> AnyPublisher<AirshipImageData, any Error> in
                guard let httpResponse = response.response as? HTTPURLResponse,
                      httpResponse.statusCode == 200
                else {
                    return Fail(
                        error: AirshipErrors.error("failed to fetch message")
                    )
                    .eraseToAnyPublisher()
                }

                do {
                    let imageData = try AirshipImageData(data: response.data)
                    return Just(imageData)
                        .setFailureType(to: (any Error).self)
                        .eraseToAnyPublisher()
                } catch {
                    return Fail(error: error)
                        .eraseToAnyPublisher()
                }
            }
            .catch { error in
                return Fail(
                    error: AirshipErrors.error("failed to fetch message")
                )
                .delay(
                    for: .seconds(AirshipImageLoader.retryDelay),
                    scheduler: DispatchQueue.global()
                )
                .eraseToAnyPublisher()
            }
            .switchToLatest()
            .retry(AirshipImageLoader.retries)
            .eraseToAnyPublisher()
    }
}
