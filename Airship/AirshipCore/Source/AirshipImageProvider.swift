/* Copyright Airship and Contributors */

public import Foundation
@_spi(AirshipInternal) import AirshipBasement

/// Image provider to extend image loading.
/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
@MainActor
public protocol AirshipImageProvider: Sendable {

    /// Returns image data for the given URL when this provider can satisfy the request
    /// - Parameters:
    ///     - url: The image URL.
    /// - Returns: The image or nil to let the image loader fetch it.
    func get(url: URL) -> AirshipImageData?

    /// Adds a child image cache. Used for dynamically add or remove cached content
    /// - Parameter cache: The cache to add
    /// - Returns: The cache token. the token could be used for removing the cache.
    func tryAddChild(_ cache: any AirshipImageProvider) -> String?

    /// Removes a child image cache
    /// - Parameter token: The cache token
    func removeChild(token: String)
}
