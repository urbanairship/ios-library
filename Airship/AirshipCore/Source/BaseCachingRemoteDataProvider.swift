/* Copyright Airship and Contributors */

import Foundation
import Combine

protocol CachingRemoteDataProviderResult: Sendable, Equatable {
    var isSuccess: Bool { get }
    
    static func error(_ error: CachingRemoteDataError) -> any CachingRemoteDataProviderResult
}

final actor BaseCachingRemoteDataProvider<Output: CachingRemoteDataProviderResult, Overrides: Sendable> {
    private let remoteFetcher: @Sendable (String) async throws -> AirshipHTTPResponse<Output>
    private let cacheTtl: TimeInterval
    private let overridesProvider: @Sendable (String) async -> AsyncStream<Overrides>
    private let overridesApplier: @Sendable (Output, Overrides) async -> Output
    private let isEnabled: @Sendable () -> Bool
    private let taskSleeper: AirshipTaskSleeper
    private var resolvers: [String: Resolver] = [:]
    private let date: AirshipDateProtocol
    
    init(
        remoteFetcher: @Sendable @escaping (String) async throws -> AirshipHTTPResponse<Output>,
        overridesProvider: @Sendable @escaping (String) async -> AsyncStream<Overrides>,
        overridesApplier: @Sendable @escaping (Output, Overrides) async -> Output,
        isEnabled: @Sendable @escaping () -> Bool,
        date: AirshipDateProtocol = AirshipDate.shared,
        taskSleeper: AirshipTaskSleeper = .shared,
        cacheTtl: TimeInterval = 600
    ) {
        self.remoteFetcher = remoteFetcher
        self.overridesProvider = overridesProvider
        self.overridesApplier = overridesApplier
        self.taskSleeper = taskSleeper
        self.cacheTtl = cacheTtl
        self.isEnabled = isEnabled
        self.date = date
    }
    
    private func getResolver(identifier: String, lastKnownIdentifier: String?) -> Resolver {
        // The resolver for the lastKnownIdentifier can always be dropped, but we
        // can't assume the identifier (channel or contact id) is the current stable contact ID or channel ID since
        // its an async stream and we might not be on the last element.
        
        if let lastKnownIdentifier, lastKnownIdentifier != identifier {
            resolvers[lastKnownIdentifier] = nil
        }

        if let resolver = resolvers[identifier] {
            return resolver
        }

        let resolver = Resolver(
            identifier: identifier,
            overridesProvider: overridesProvider,
            remoteFetcher: remoteFetcher,
            cacheTtl: cacheTtl,
            taskSleeper: taskSleeper,
            overridesApplier: overridesApplier,
            isEnabled: isEnabled,
            date: self.date
        )

        resolvers[identifier] = resolver

        return resolver
    }
    
    func refresh() async {
        for resolver in resolvers.values {
            await resolver.expireCache()
        }
    }
    
    /// Returns the latest channel result stream from the latest stable identifier
    nonisolated func updates(identifierUpdates: AsyncStream<String>) -> AsyncStream<Output> {
        return AsyncStream { continuation in
            let fetchTask = Task { [weak self] in
                var resolverTask: Task<Void, Never>?
                var lastKnownIdentifier: String? = nil
                for await identifier in identifierUpdates {
                    resolverTask?.cancel()
                    guard !Task.isCancelled else { return }

                    guard
                        let resolver = await self?.getResolver(
                            identifier: identifier,
                            lastKnownIdentifier: lastKnownIdentifier
                        )
                    else {
                        return
                    }

                    resolverTask = Task {
                        for await update in await resolver.updates() {
                            guard !Task.isCancelled else { return }
                            continuation.yield(update)
                        }
                    }

                    lastKnownIdentifier  = identifier
                }
            }

            continuation.onTermination = { _ in
                fetchTask.cancel()
            }
        }
    }
    
    /// Manages the contact update API calls including backoff and override application
    fileprivate actor Resolver {
        private let identifier: String
        private let overridesProvider: @Sendable (String) async -> AsyncStream<Overrides>
        private let remoteFetcher: @Sendable (String) async throws -> AirshipHTTPResponse<Output>
        private let cachedValue: CachedValue<Output>
        private let fetchQueue: AirshipSerialQueue = AirshipSerialQueue()
        private let cacheTtl: TimeInterval
        private let taskSleeper: AirshipTaskSleeper
        private let overridesApplier: (Output, Overrides) async -> Output
        private let isEnabled: () -> Bool

        private let initialBackoff: TimeInterval = 8.0
        private let maxBackoff: TimeInterval = 64.0
        private var lastResults: [String: Output] = [:]
        
        private var waitTask: Task<Void, Never>? = nil

        func expireCache() {
            cachedValue.expire()
            waitTask?.cancel()
        }

        init(
            identifier: String,
            overridesProvider: @Sendable @escaping (String) async -> AsyncStream<Overrides>,
            remoteFetcher: @Sendable @escaping (String) async throws -> AirshipHTTPResponse<Output>,
            cacheTtl: TimeInterval,
            taskSleeper: AirshipTaskSleeper,
            overridesApplier: @escaping (Output, Overrides) async -> Output,
            isEnabled: @escaping () -> Bool,
            date: AirshipDateProtocol
        ) {
            self.identifier = identifier
            self.overridesProvider = overridesProvider
            self.remoteFetcher = remoteFetcher
            self.cacheTtl = cacheTtl
            self.taskSleeper = taskSleeper
            self.overridesApplier = overridesApplier
            self.isEnabled = isEnabled
            self.cachedValue = CachedValue(date: date)
        }

        func updates() -> AsyncStream<Output> {
            let id = UUID().uuidString

            return AsyncStream { continuation in
                let refreshTask = Task {
                    var backoff = self.initialBackoff

                    repeat {
                        let fetched = await self.fetch()
                        let workingResult = if fetched.isSuccess {
                            fetched
                        } else if let lastResult = lastResults[id], lastResult.isSuccess {
                            lastResult
                        } else {
                            fetched
                        }

                        guard !Task.isCancelled else { return }

                        let overrideUpdates = await self.overridesProvider(identifier)

                        let updateTask = Task {
                            for await overrides in overrideUpdates {
                                guard !Task.isCancelled else {
                                    return
                                }
                                
                                let result = await overridesApplier(workingResult, overrides)

                                if (lastResults[id] != result) {
                                    continuation.yield(result)
                                    lastResults[id] = result
                                }
                            }
                        }
                        
                        let timeToWait: TimeInterval
                        
                        if (fetched.isSuccess) {
                            timeToWait = cachedValue.timeRemaining
                            backoff = self.initialBackoff
                        } else {
                            timeToWait = backoff
                            
                            if backoff < self.maxBackoff {
                                backoff = backoff * 2
                            }
                        }
                        
                        waitTask = Task {
                            try? await self.taskSleeper.sleep(timeInterval: timeToWait)
                        }
                        
                        await waitTask?.value

                        updateTask.cancel()
                    } while (!Task.isCancelled)
                }

                continuation.onTermination = { _ in
                    refreshTask.cancel()
                }
            }
        }

        private func fetch() async -> Output {
            guard isEnabled() else {
                return Output.error(.disabled) as! Output
            }

            return await self.fetchQueue.runSafe { [cachedValue, remoteFetcher, identifier, cacheTtl] in
                
                if let cached = cachedValue.value {
                    return cached
                }

                do {
                    let response = try await remoteFetcher(identifier)

                    guard response.isSuccess, let outputData = response.result else {
                        throw AirshipErrors.error("Failed to fetch associated channels list")
                    }
                    
                    cachedValue.set(value: outputData, expiresIn: cacheTtl)

                    return outputData
                    
                } catch {
                    AirshipLogger.warn(
                        "Received error when fetching contact channels \(error))"
                    )

                    return Output.error(.failedToFetch) as! Output
                }
            }
        }
    }
}

enum CachingRemoteDataError: Error, Equatable, Sendable, Hashable {
    case disabled
    case failedToFetch
}
