/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Actual airship component for AirshipDebugManager. Used to hide AirshipComponent methods.
final class DebugComponent : AirshipComponent, AirshipPushableComponent {
    final let debugManager: AirshipDebugManager

    init(debugManager: AirshipDebugManager) {
        self.debugManager = debugManager
    }
}

