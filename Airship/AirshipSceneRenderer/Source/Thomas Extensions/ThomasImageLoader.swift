/* Copyright Airship and Contributors */

import Foundation
@_spi(AirshipInternal) public import AirshipBasement

/// Loads and prefetches images for a Thomas layout. Host-provided so the renderer doesn't reach
/// into a particular image cache; the loader owns the lifecycle of anything it prefetches and
/// releases it all when the owning environment asks it to (on dismiss).
/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public protocol ThomasImageLoader: Sendable {
    /// Loads the image at the given URL (from cache if available).
    @MainActor
    func load(url: String) async throws -> AirshipImageData

    /// Prefetches the given image assets so subsequent `load` calls resolve from cache. The loader
    /// tracks whatever it prefetched internally; callers never see a token.
    @MainActor
    func prefetch(urls: [String]) async throws

    /// Releases every asset the loader has prefetched. Called by the environment on dismiss.
    @MainActor
    func releaseAll()
}
