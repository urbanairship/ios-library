/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Airship rendering engine extensions.
/// - Note: for internal use only.  :nodoc:
struct InAppMessageExtensions {
#if !os(tvOS)
    let nativeBridgeExtension: NativeBridgeExtensionDelegate?
#endif
    
    let imageProvider: AirshipImageProvider?
    let actionRunner: InAppActionRunner?
}
