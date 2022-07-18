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
private struct VisibleEnvironmentKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

@available(iOS 13.0.0, tvOS 13.0, *)
private struct LayoutStateEnvironmentKey: EnvironmentKey {
    static let defaultValue: LayoutState = LayoutState.empty
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
    
    var isVisible: Bool {
        get { self[VisibleEnvironmentKey.self] }
        set { self[VisibleEnvironmentKey.self] = newValue }
    }
    
    var layoutState: LayoutState {
        get { self[LayoutStateEnvironmentKey.self] }
        set { self[LayoutStateEnvironmentKey.self] = newValue }
    }
    
}


@available(iOS 13.0.0, tvOS 13.0, *)
extension View {
    func setVisible(_ visible: Bool) -> some View {
        environment(\.isVisible, visible)
    }
}
