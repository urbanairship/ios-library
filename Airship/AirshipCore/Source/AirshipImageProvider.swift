/* Copyright Airship and Contributors */

/// Image provider to extend image loading.
/// - Note: for internal use only.  :nodoc:
public protocol AirshipImageProvider {

    /// Gets the an image.
    /// - Parameters:
    ///     - url: The image URL.
    /// - Returns: The image or nil to let the image loader fetch it.
    func get(url: URL) -> AirshipImageData?
}
