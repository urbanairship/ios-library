/* Copyright Airship and Contributors */

import Foundation

extension AirshipAI {
    final class ProviderRegistry: Sendable {

        private struct AnyProvider: Sendable {
            let fetch: @Sendable (any Sendable) async -> AirshipAI.Context
        }

        @MainActor
        private var providers: [String: AnyProvider] = [:]

        @MainActor
        private var defaultProvider: AnyProvider?

        init() {}

        @MainActor
        func setContextProvider<S: Sendable>(for usage: Usage<S>, _ provider: ContextProvider<S>?) {
            if let provider {
                providers[usage.rawValue] = AnyProvider { subject in
                    guard let typed = subject as? S else { return .empty }
                    return await provider(typed)
                }
            } else {
                providers.removeValue(forKey: usage.rawValue)
            }
        }

        @MainActor
        func setDefaultContextProvider(_ provider: (@Sendable () async -> AirshipAI.Context)?) {
            if let provider {
                defaultProvider = AnyProvider { _ in await provider() }
            } else {
                defaultProvider = nil
            }
        }

        /// Returns a type-erased context fetcher for the given usage raw value, or nil if
        /// no provider is registered.
        ///
        /// The lookup is main-actor-isolated because the registry's state is; the
        /// returned fetcher is not, so the provider runs with whatever isolation it
        /// declares for itself.
        ///
        /// A usage-specific provider wins outright; the default provider is only a
        /// fallback for usages that have none. The two are never combined.
        @MainActor
        func contextFetcher(
            for rawValue: String
        ) -> (@Sendable (any Sendable) async -> AirshipAI.Context)? {
            (providers[rawValue] ?? defaultProvider)?.fetch
        }
    }
}
