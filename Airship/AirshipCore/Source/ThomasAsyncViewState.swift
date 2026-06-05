/* Copyright Airship and Contributors */

import Combine
import Foundation

@MainActor
final class ThomasAsyncViewState: ObservableObject {
    
    private static let assetCacheRootComponent = "com.airship.layout.assets"
    
    let properties: ThomasViewInfo.AsyncViewController.Properties?

    private let taskSleeper: any AirshipTaskSleeper
    private let requestSession: any AirshipRequestSession
    private let channelIdFetcher: (() async throws -> String)
    private let contactIdFetcher: (() async throws -> String)
    private let assetCacheManager: (any AssetCacheManagerProtocol)?
    private var resolveTask: Task<Void, Never>?
    private var imageCacheChildId: String?
    private(set) weak var thomasEnvironment: ThomasEnvironment?

    /// Layout decoded from HTTP that still needs a successful image prefetch before `response` is published.
    private(set) var resolvedLayoutAwaitingPrefetch: ThomasViewInfo?
    
    init(
        properties: ThomasViewInfo.AsyncViewController.Properties? = nil,
        taskSleeper: any AirshipTaskSleeper = DefaultAirshipTaskSleeper.shared,
        requestSession: (any AirshipRequestSession)? = nil,
        channelIdFetcher: (() async throws -> String)? = nil,
        contactIdFetcher: (() async throws -> String)? = nil,
        assetCacheManager: (any AssetCacheManagerProtocol)? = nil
    ) {
        self.properties = properties
        self.taskSleeper = taskSleeper
        self.requestSession = requestSession ?? Airship.config.requestSession
        self.assetCacheManager = assetCacheManager ?? AssetCacheManager(
            assetFileManager: DefaultAssetFileManager(
                rootPathComponent: Self.assetCacheRootComponent,
                rootLocation: .temporaryDirectory
            )
        )
        self.channelIdFetcher = channelIdFetcher ?? {
            // Wait for channel ID from identifierUpdates stream
            var iterator = Airship.channel.identifierUpdates.makeAsyncIterator()
            guard let channelID = await iterator.next() else {
                throw AsyncRequestError.client
            }
            return channelID
        }
        
        self.contactIdFetcher = contactIdFetcher ?? {
            guard let internalContact = Airship.contact as? any InternalAirshipContact else {
                throw AsyncRequestError.client
            }
            return await internalContact.getStableContactID()
        }
    }
    
    func configure(thomasEnvironment: ThomasEnvironment) {
        self.thomasEnvironment = thomasEnvironment
        thomasEnvironment.registerDismissCleanup(for: self) { [weak self] in
            guard let self else { return }
            Self.removeImageChildAndClearCache(
                childId: self.imageCacheChildId,
                environment: self.thomasEnvironment,
                cacheIdentifier: self.properties?.identifier,
                manager: self.assetCacheManager
            )
        }
    }

    deinit {
        resolveTask?.cancel()
        let childId = imageCacheChildId
        let environment = thomasEnvironment
        let cacheIdentifier = properties?.identifier
        let manager = assetCacheManager
        Task { @MainActor in
            Self.removeImageChildAndClearCache(
                childId: childId,
                environment: environment,
                cacheIdentifier: cacheIdentifier,
                manager: manager
            )
        }
    }
    
    @MainActor
    private static func removeImageChildAndClearCache(
        childId: String?,
        environment: ThomasEnvironment?,
        cacheIdentifier: String?,
        manager: (any AssetCacheManagerProtocol)?
    ) {
        if let childId {
            environment?.extensions?.imageProvider?.removeChild(token: childId)
        }
        if let cacheIdentifier, let manager {
            Task {
                await manager.clearCache(identifier: cacheIdentifier)
            }
        }
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
    var response: ThomasViewInfo?
    
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
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return .timedOut
            default:
                return .client
            }
        }
        
        if let asyncError = error as? AsyncRequestError {
            switch asyncError {
            case .client:
                return .client
            case .server(let statusCode):
                return .server(statusCode: statusCode)
            case .prefetchFailed:
                return .imagePrefetchFailed
            }
        }
        
        return .client
    }
    
    /// Only HTTP 5xx responses are retried; 4xx and other errors fail immediately.
    private func isRetryableServerError(_ error: any Error) -> Bool {
        guard let asyncError = error as? AsyncRequestError,
              case .server(let statusCode) = asyncError else {
            return false
        }
        return (500..<600).contains(statusCode)
    }
    
    func resolve() async throws {
        try Task.checkCancellation()
        
        guard let properties else {
            throw AsyncRequestError.client
        }
        
        guard case .content(let info) = properties.request else {
            throw AsyncRequestError.client
        }
        
        let retry = properties.retry
        var lastError: (any Error)?
        
        for attempt in 0...retry.maxRetries {
            try Task.checkCancellation()

            let delay = calculateBackoff(attempt: attempt, retryPolicy: retry)
            try await taskSleeper.sleep(timeInterval: delay)
            
            do {
                let httpResponse = try await makeRequest(info)
                guard let viewInfo = httpResponse.result else {
                    throw AsyncRequestError.client
                }
                resolvedLayoutAwaitingPrefetch = nil
                try await commitResolvedLayout(viewInfo)
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
        
        throw lastError ?? AsyncRequestError.client
    }
    
    private func imageURLStrings(from layout: ThomasViewInfo) -> [String] {
        layout.urlInfos.compactMap { info in
            if case .image(let url, _) = info {
                return url
            }
            return nil
        }
    }

    /// Publishes `response` only after any required image prefetch and provider registration complete.
    private func commitResolvedLayout(_ viewInfo: ThomasViewInfo) async throws {
        if let imageCache = thomasEnvironment?.extensions?.imageProvider {
            if let current = imageCacheChildId {
                imageCache.removeChild(token: current)
                imageCacheChildId = nil
            }

            let assets = imageURLStrings(from: viewInfo)
            let mustPrefetch = !assets.isEmpty
                && assetCacheManager != nil
                && properties?.identifier != nil

            do {
                if let child = try await prefetchImageChild(
                    assets: assets,
                    blocking: mustPrefetch
                ) {
                    imageCacheChildId = imageCache.tryAddChild(child)
                }
            } catch {
                if mustPrefetch {
                    resolvedLayoutAwaitingPrefetch = viewInfo
                }
                throw error
            }
        }

        resolvedLayoutAwaitingPrefetch = nil
        self.response = viewInfo
    }

    /// When `blocking` is true, a failed download prevents publishing `response` until retry.
    private func prefetchImageChild(
        assets: [String],
        blocking: Bool
    ) async throws -> (any AirshipImageProvider)? {
        guard !assets.isEmpty else { return nil }

        guard let manager = assetCacheManager,
              let identifier = properties?.identifier
        else {
            return nil
        }

        let cachedAssets: any AirshipCachedAssetsProtocol
        do {
            cachedAssets = try await manager.cacheAssets(
                identifier: identifier,
                assets: assets
            )
        } catch {
            if blocking {
                throw AsyncRequestError.prefetchFailed
            }
            return nil
        }

        return NonExtendableAssetCacheImageProvider { url in
            guard
                let url = cachedAssets.cachedURL(remoteURL: url),
                let data = FileManager.default.contents(atPath: url.path),
                let imageData = try? AirshipImageData(data: data)
            else {
                return nil
            }
            return imageData
        }
    }


    // MARK: - HTTP
    
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
    
    private func makeRequest(
        _ info: ThomasViewInfo.AsyncViewController.Request.ContentRequest
    ) async throws -> AirshipHTTPResponse<ThomasViewInfo> {
        
        let resolvedAuth: AirshipRequestAuth?
        switch info.auth {
        case .app:
            resolvedAuth = .generatedAppToken
        case .channel:
            let channelID = try await channelIdFetcher()
            resolvedAuth = .generatedChannelToken(identifier: channelID)
        case .contact:
            let contactID = try await contactIdFetcher()
            resolvedAuth = .contactAuthToken(identifier: contactID)
        case .none:
            resolvedAuth = nil
        }
        
        let airshipRequest = AirshipRequest(
            url: info.url,
            method: "GET",
            auth: resolvedAuth
        )
        
        return try await requestSession.performHTTPRequest(airshipRequest) { (data, response) in
            guard let data = data, response.isSuccessfulHTTPStatus else {
                throw AsyncRequestError.server(statusCode: response.statusCode)
            }
            do {
                return try JSONDecoder().decode(ThomasViewInfo.self, from: data)
            } catch {
                throw AsyncRequestError.client
            }
        }
    }
}

private enum AsyncRequestError: Error {
    case client
    case server(statusCode: Int)
    case prefetchFailed
}

private extension HTTPURLResponse {
    var isSuccessfulHTTPStatus: Bool {
        (200...299).contains(statusCode)
    }
}
