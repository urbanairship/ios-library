/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Airship rendering engine extensions.
/// - Note: for internal use only.  :nodoc:
struct InAppMessageExtensions {
    let nativeBridgeExtension: NativeBridgeExtensionDelegate?
    let imageProvider: AirshipImageProvider?
    let actionRunner: InAppActionRunner?
}
