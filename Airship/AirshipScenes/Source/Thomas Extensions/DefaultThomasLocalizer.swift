/* Copyright Airship and Contributors */

@_spi(AirshipInternal) import AirshipSceneRenderer
@_spi(AirshipInternal) import AirshipCore
import Foundation

/// The localizer the SDK wires up by default — resolves strings from Airship's resource bundle.
struct DefaultThomasLocalizer: ThomasLocalizer {
    func localizedString(key: String) -> String? {
        AirshipResources.localizedString(key: key)
    }
}
