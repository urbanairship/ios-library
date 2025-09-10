/* Copyright Airship and Contributors */

import Combine
import Foundation
public import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AirshipCore)
import AirshipCore
#endif

/// The main view for the Airship Message Center. This view provides a navigation stack.
/// If you wish to provide your own navigation, see `MessageCenterContent`.
public struct MessageCenterView: View {

    /// The navigation style.
    public enum NavigationStyle: Sendable {
        /// A navigation style that uses a split view on larger devices and a stack view on smaller devices.
        case split
        /// A navigation style that uses a stack view.
        case stack
        /// The default navigation style. Defers to `split` on larger devices and `stack` on smaller devices.
        case auto
    }

    private let navigationStyle: NavigationStyle

    @ObservedObject
    private var controller: MessageCenterController

    @Environment(\.airshipMessageCenterPredicate)
    private var predicate

    /// Initializer.
    /// - Parameters:
    ///   - navigationStyle: The navigation style. Defaults to `auto`.
    ///   - controller: The message center controller. If `nil` the default controller will be used.
    public init(navigationStyle: NavigationStyle = .auto, controller: MessageCenterController? = nil) {
        self.navigationStyle = navigationStyle
        self.controller = controller ?? (Airship.isFlying ? Airship.messageCenter.controller : MessageCenterController())
    }

    private var shouldUseSplit: Bool {
        switch navigationStyle {
        case .split:
            return true
        case .stack:
            return false
        case .auto:
#if canImport(UIKit)
            return UIDevice.current.userInterfaceIdiom == .pad || UIDevice.current.userInterfaceIdiom == .tv
#else
            return true // fallback for macOS, etc.
#endif
        }
    }

    /// The body of the view.
    public var body: some View {
        Group {
            if shouldUseSplit {
                MessageCenterNavigationSplitView(controller: controller, predicate: self.predicate)
            } else {
                MessageCenterNavigationStack(controller: controller, predicate: self.predicate)
            }
        }
    }
}

extension EnvironmentValues {
    var messageCenterDismissAction: (@MainActor @Sendable () -> Void)? {
        get { self[MessageCenterDismissActionKey.self] }
        set { self[MessageCenterDismissActionKey.self] = newValue }
    }
}

private struct MessageCenterDismissActionKey: EnvironmentKey {
    static let defaultValue: (@MainActor @Sendable () -> Void)? = nil
}

internal extension View {
    func addMessageCenterDismissAction(action: (@MainActor @Sendable () -> Void)?) -> some View {
        environment(\.messageCenterDismissAction, action)
    }
}

struct MessageCenterUIKitContextModifier: ViewModifier {
    let hostingControllerRef: MessageCenterUIKitAppearance.WeakReference<UIViewController>
    @State private var detectedAppearance: MessageCenterUIKitAppearance.DetectedAppearance?

    func body(content: Content) -> some View {
        content
            .environment(\.messageCenterDetectedAppearance, detectedAppearance)
            .applyUIKitNavigationAppearance()
            .background(
                MessageCenterAppearanceDetector(
                    detectedAppearance: $detectedAppearance,
                    hostingControllerRef: hostingControllerRef
                )
                .frame(width: 0, height: 0)
                .hidden()
            )
    }
}
