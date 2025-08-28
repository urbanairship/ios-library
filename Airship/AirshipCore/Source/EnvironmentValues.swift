/* Copyright Airship and Contributors */


import SwiftUI

private struct OrientationKey: EnvironmentKey {
    static let defaultValue: ThomasOrientation? = nil
}

private struct WindowSizeKey: EnvironmentKey {
    static let defaultValue: ThomasWindowSize? = nil
}

private struct VoiceOverRunningKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

private struct VisibleEnvironmentKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

private struct ButtonActionsEnabledKey: EnvironmentKey {
    static let defaultValue: Bool = true
}

private struct PageIdentifierKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

private struct ThomasAssociatedLabelResolverKey: EnvironmentKey {
    static let defaultValue: ThomasAssociatedLabelResolver? = nil
}

private struct LayoutStateEnvironmentKey: EnvironmentKey {
    static let defaultValue: LayoutState = LayoutState.empty
}

extension EnvironmentValues {
    var orientation: ThomasOrientation? {
        get { self[OrientationKey.self] }
        set { self[OrientationKey.self] = newValue }
    }

    var windowSize: ThomasWindowSize? {
        get { self[WindowSizeKey.self] }
        set { self[WindowSizeKey.self] = newValue }
    }

    var isVoiceOverRunning: Bool {
        get { self[VoiceOverRunningKey.self] }
        set { self[VoiceOverRunningKey.self] = newValue }
    }

    var isVisible: Bool {
        get { self[VisibleEnvironmentKey.self] }
        set { self[VisibleEnvironmentKey.self] = newValue }
    }

    var isButtonActionsEnabled: Bool {
        get { self[ButtonActionsEnabledKey.self] }
        set { self[ButtonActionsEnabledKey.self] = newValue }
    }

    var pageIdentifier: String? {
        get { self[PageIdentifierKey.self] }
        set { self[PageIdentifierKey.self] = newValue }
    }

    var thomasAssociatedLabelResolver: ThomasAssociatedLabelResolver? {
        get { self[ThomasAssociatedLabelResolverKey.self] }
        set { self[ThomasAssociatedLabelResolverKey.self] = newValue }
    }


    internal var layoutState: LayoutState {
        get { self[LayoutStateEnvironmentKey.self] }
        set { self[LayoutStateEnvironmentKey.self] = newValue }
    }
}

extension View {
    func setVisible(_ visible: Bool) -> some View {
        environment(\.isVisible, visible)
    }
}
