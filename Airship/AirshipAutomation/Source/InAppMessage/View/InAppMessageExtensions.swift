/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Airship rendering engine extensions.
/// - Note: for internal use only.  :nodoc:
struct InAppMessageExtensions {
#if !os(tvOS)
    let nativeBridgeExtension: (any NativeBridgeExtensionDelegate)?
#endif
    
    let imageProvider: (any AirshipImageProvider)?
    let actionRunner: (any InAppActionRunner)?
}
