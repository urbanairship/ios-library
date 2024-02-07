/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Airship rendering engine extensions.
/// - Note: for internal use only.  :nodoc:
public struct InAppMessageExtensions {
    let nativeBridgeExtension: NativeBridgeExtensionDelegate?

    let imageProvider: AirshipImageProvider?

    public init(
        nativeBridgeExtension: NativeBridgeExtensionDelegate? = nil,
        imageProvider: AirshipImageProvider? = nil
    ) {
        self.nativeBridgeExtension = nativeBridgeExtension
        self.imageProvider = imageProvider
    }
}
