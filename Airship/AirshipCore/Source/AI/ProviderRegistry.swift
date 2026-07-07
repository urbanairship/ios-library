/* Copyright Airship and Contributors */

import Foundation

extension AirshipAI {
    final class ProviderRegistry: Sendable {

        @MainActor
        private var providers: [Usage: any ContextProvider] = [:]

        init() {}

        @MainActor
        func setProvider(_ provider: (any ContextProvider)?, for usage: Usage) {
            providers[usage] = provider
        }

        @MainActor
        func provider(for usage: Usage) -> (any ContextProvider)? {
            providers[usage]
        }
    }
}
