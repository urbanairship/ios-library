/* Copyright Airship and Contributors */

import Combine
import Foundation
@_spi(AirshipInternal) import AirshipBasement

@MainActor
final class ThomasAsyncViewState: ObservableObject {

    let properties: ThomasViewInfo.AsyncViewController.Properties?

    private let taskSleeper: any AirshipTaskSleeper
    private let resolver: (any AsyncViewResolver)?
    private let imageLoader: (any ThomasImageLoader)?
    private var resolveTask: Task<Void, Never>?

    /// Layout decoded from HTTP that still needs a successful image prefetch before `response` is published.
    private(set) var resolvedLayoutAwaitingPrefetch: ThomasAsyncViewContent?

    init(
        properties: ThomasViewInfo.AsyncViewController.Properties? = nil,
        resolver: (any AsyncViewResolver)? = nil,
        imageLoader: (any ThomasImageLoader)? = nil,
        taskSleeper: any AirshipTaskSleeper = DefaultAirshipTaskSleeper.shared
    ) {
        self.properties = properties
        self.resolver = resolver
        self.imageLoader = imageLoader
        self.taskSleeper = taskSleeper
    }

    deinit {
        resolveTask?.cancel()
    }

    enum Status: Encodable, Sendable, Equatable, Hashable {
        case loading
        case loaded
        case error(ErrorInfo)

        enum CodingKeys: CodingKey {
            case status
            case error
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .loading:
                try container.encode("loading", forKey: .status)
            case .loaded:
                try container.encode("loaded", forKey: .status)
            case .error(let error):
                try container.encode("error", forKey: .status)
                try container.encode(error, forKey: .error)
            }
        }
    }

    enum ErrorInfo: Encodable, Sendable, Equatable, Hashable {
        case client
        case timedOut
        case server(statusCode: Int)
        case imagePrefetchFailed

        enum CodingKeys: String, CodingKey {
            case type
            case statusCode = "http_status_code"
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .client:
                try container.encode("client_error", forKey: .type)
            case .timedOut:
                try container.encode("timeout", forKey: .type)
            case .server(let statusCode):
                try container.encode("server_error", forKey: .type)
                try container.encode(statusCode, forKey: .statusCode)
            case .imagePrefetchFailed:
                try container.encode("image_prefetch_failed", forKey: .type)
            }
        }
    }

    @Published
    var response: ThomasAsyncViewContent?

    @Published
    var status: Status = .loading

    func retry() {
        guard resolveTask == nil, response == nil else { return }
        status = .loading
        resolveTask = Task { @MainActor [weak self] in
            defer {
                self?.resolveTask = nil
            }
            guard let self else { return }
            do {
                if let pending = self.resolvedLayoutAwaitingPrefetch {
                    try await self.commitResolvedLayout(pending)
                } else {
                    try await self.resolve()
                }
                self.status = .loaded
            } catch is CancellationError {
                return
            } catch {
                self.status = .error(self.categorizeError(error))
                AirshipLogger.error("Failed to resolve async view: \(error)")
            }
        }
    }

    private func categorizeError(_ error: any Error) -> ErrorInfo {
        if let urlError = error as? URLError, urlError.code == .timedOut {
            return .timedOut
        }

        if let resolverError = error as? AsyncViewResolverError {
            switch resolverError {
            case .client:
                return .client
            case .server(let statusCode):
                return .server(statusCode: statusCode)
            case .timedOut:
                return .timedOut
            }
        }

        if error is PrefetchError {
            return .imagePrefetchFailed
        }

        return .client
    }

    /// Only HTTP 5xx responses are retried; 4xx and other errors fail immediately.
    private func isRetryableServerError(_ error: any Error) -> Bool {
        guard let resolverError = error as? AsyncViewResolverError,
              case .server(let statusCode) = resolverError else {
            return false
        }
        return (500..<600).contains(statusCode)
    }

    func resolve() async throws {
        try Task.checkCancellation()

        guard let properties else {
            throw AsyncViewResolverError.client
        }

        guard case .content(let info) = properties.request else {
            throw AsyncViewResolverError.client
        }

        let retry = properties.retry
        var lastError: (any Error)?

        for attempt in 0...retry.maxRetries {
            try Task.checkCancellation()

            let delay = calculateBackoff(attempt: attempt, retryPolicy: retry)
            try await taskSleeper.sleep(timeInterval: delay)

            do {
                let content = try await makeRequest(info)
                resolvedLayoutAwaitingPrefetch = nil
                try await commitResolvedLayout(content)
                return
            } catch {
                if error is CancellationError {
                    throw error
                }

                lastError = error

                guard isRetryableServerError(error) else {
                    throw error
                }
            }
        }

        throw lastError ?? AsyncViewResolverError.client
    }

    private func imageURLStrings(from layout: ThomasViewInfo) -> [String] {
        layout.urlInfos.compactMap { info in
            if case .image(let url, _) = info {
                return url
            }
            return nil
        }
    }

    /// Publishes `response` only after any required image prefetch completes. The image loader owns
    /// the prefetched assets and releases them on dismiss.
    private func commitResolvedLayout(_ content: ThomasAsyncViewContent) async throws {
        let imageURLs = imageURLStrings(from: content.view)
        do {
            if !imageURLs.isEmpty {
                try await imageLoader?.prefetch(urls: imageURLs)
            }
        } catch {
            resolvedLayoutAwaitingPrefetch = content
            throw PrefetchError(underlying: error)
        }

        resolvedLayoutAwaitingPrefetch = nil
        self.response = content
    }

    /// Delay before each resolve attempt. `attempt` is the loop index (sleep-then-request).
    /// - `attempt == 0`: no wait before the first request.
    /// - `attempt >= 1`: `min(initialBackoff * 2^(attempt - 1), maxBackoff)` before subsequent attempts.
    private func calculateBackoff(
        attempt: Int,
        retryPolicy: ThomasViewInfo.AsyncViewController.RetryingConfig
    ) -> TimeInterval {
        if attempt == 0 {
            return 0
        }

        return min(
            retryPolicy.initialBackoff * pow(2.0, Double(attempt - 1)),
            retryPolicy.maxBackoff
        )
    }

    /// Resolves the request through the host-provided resolver and decodes the layout. Decoding
    /// stays in the renderer; the resolver only returns the raw payload.
    private func makeRequest(
        _ info: ThomasViewInfo.AsyncViewController.Request.ContentRequest
    ) async throws -> ThomasAsyncViewContent {
        guard let resolver else {
            throw AsyncViewResolverError.client
        }

        let auth: ThomasAsyncViewAuth = switch info.auth {
        case .app?: .app
        case .channel?: .channel
        case .contact?: .contact
        case nil: .none
        }

        let data = try await resolver.resolve(url: info.url, auth: auth)

        do {
            return try JSONDecoder().decode(ThomasAsyncViewContent.self, from: data)
        } catch {
            throw AsyncViewResolverError.client
        }
    }
}

/// What an async view's request returns: the view to draw, whose root may also name colors.
///
/// Within the async view, a color reference looks in these first and then in the scene's, so a name
/// defined here overrides the scene's for this content only.
struct ThomasAsyncViewContent: Decodable, Equatable, Sendable {
    let view: ThomasViewInfo
    let references: ThomasSceneReferences?

    private enum CodingKeys: String, CodingKey {
        case references
    }

    init(from decoder: any Decoder) throws {
        self.view = try ThomasViewInfo(from: decoder)
        self.references = try decoder.container(keyedBy: CodingKeys.self)
            .decodeIfPresent(ThomasSceneReferences.self, forKey: .references)
    }
}

/// Internal marker for an image prefetch failure during async-view resolution.
private struct PrefetchError: Error, CustomStringConvertible {
    let underlying: any Error
    var description: String { "PrefetchError(underlying: \(underlying))" }
}
