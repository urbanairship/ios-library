/* Copyright Airship and Contributors */

import Foundation

extension AirshipAI {
    final class ProviderRegistry: Sendable {

        private struct AnyProvider: Sendable {
            let fetch: @Sendable @MainActor (any Sendable) async -> AirshipAI.Context
        }

        @MainActor
        private var providers: [String: AnyProvider] = [:]

        @MainActor
        private var defaultProvider: AnyProvider?

        init() {}

        @MainActor
        func setProvider<S: Sendable>(_ provider: (any ContextProvider<S>)?, for usage: Usage<S>) {
            if let provider {
                providers[usage.rawValue] = AnyProvider { subject in
                    guard let typed = subject as? S else { return .empty }
                    return await provider.context(for: typed)
                }
            } else {
                providers.removeValue(forKey: usage.rawValue)
            }
        }

        @MainActor
        func setDefaultProvider(_ provider: (any ContextProvider<Void>)?) {
            if let provider {
                defaultProvider = AnyProvider { _ in
                    await provider.context(for: ())
                }
            } else {
                defaultProvider = nil
            }
        }

        /// Returns a type-erased context fetcher for the given usage raw value, or nil if
        /// no provider is registered. The returned closure merges default and typed contexts;
        /// typed provider items come after the default provider's.
        @MainActor
        func contextFetcher(
            for rawValue: String
        ) -> (@Sendable @MainActor (any Sendable) async -> AirshipAI.Context)? {
            let typed = providers[rawValue]
            let def = defaultProvider

            guard typed != nil || def != nil else { return nil }

            return { subject in
                let defCtx: AirshipAI.Context
                if let def {
                    defCtx = await def.fetch(subject)
                } else {
                    defCtx = .empty
                }
                let typedCtx: AirshipAI.Context
                if let typed {
                    typedCtx = await typed.fetch(subject)
                } else {
                    typedCtx = .empty
                }
                return defCtx.merged(overriddenBy: typedCtx)
            }
        }
    }
}

private extension AirshipAI.Context {
    func merged(overriddenBy other: AirshipAI.Context) -> AirshipAI.Context {
        // Typed provider items come after default items — when priorities tie,
        // models drop the earlier (default) items first when trimming.
        AirshipAI.Context(items: items + other.items)
    }
}
