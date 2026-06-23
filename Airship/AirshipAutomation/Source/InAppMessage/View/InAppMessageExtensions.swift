/* Copyright Airship and Contributors */

import Foundation

@_spi(AirshipInternal) import AirshipCore

/// Airship rendering engine extensions.
struct InAppMessageExtensions {
#if !os(tvOS)
    let nativeBridgeExtension: (any NativeBridgeExtensionDelegate)?
#endif
    
    let imageProvider: (any AirshipImageProvider)?
    let actionRunner: (any InAppActionRunner)?
}
