/* Copyright Airship and Contributors */

import Foundation

/// Image provider to extend image loading.
/// - Note: for internal use only.  :nodoc:
@objc(UAImageProvider)
public protocol ImageProvider {
    
    /// Gets the an image.
    /// - Parameters:
    ///     - url: The image URL.
    /// - Returns: The image or nil to let the image loader fetch it.
    @objc
    func get(url: URL) -> UIImage?
}
