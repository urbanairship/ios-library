/* Copyright Airship and Contributors */

import Foundation
import Combine

@testable import AirshipAutomationSwift
@testable import AirshipCore

final class TestCachedAssets: AirshipCachedAssetsProtocol {

    func cachedURL(remoteURL: URL) -> URL? {
        return nil
    }
    
    func isCached(remoteURL: URL) -> Bool {
        return false
    }
}

final actor TestAssetManager: AssetCacheManagerProtocol {
    var cleared: [String] = []
    var onCache: (@Sendable (String, [String]) async throws -> AirshipCachedAssetsProtocol)?

    func setOnCache(_ onCache: @escaping @Sendable (String, [String]) async throws -> AirshipCachedAssetsProtocol) {
        self.onCache = onCache
    }

    func cacheAssets(identifier: String, assets: [String]) async throws -> AirshipCachedAssetsProtocol {
        try await self.onCache!(identifier, assets)
    }
    
    func clearCache(identifier: String) async {
        cleared.append(identifier)
    }

}
