/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
private struct OrientationKey: EnvironmentKey {
    static let defaultValue: Orientation? = nil
}

@available(iOS 13.0.0, tvOS 13.0, *)
private struct WindowSizeKey: EnvironmentKey {
    static let defaultValue: WindowSize? = nil
}


@available(iOS 13.0.0, tvOS 13.0, *)
extension EnvironmentValues {
    var orientation: Orientation? {
        get { self[OrientationKey.self] }
        set { self[OrientationKey.self] = newValue }
    }

    var windowSize: WindowSize? {
        get { self[WindowSizeKey.self] }
        set { self[WindowSizeKey.self] = newValue }
    }
}

