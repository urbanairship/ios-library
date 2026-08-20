/* Copyright Airship and Contributors */

import Combine
import Foundation
public import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

import AirshipCore

/// The main view for the Airship Message Center. This view provides a navigation stack.
/// If you wish to provide your own navigation, see `MessageCenterContent`.
public struct MessageCenterView: View {

    /// The navigation style.
    public enum NavigationStyle: Sendable {
        /// A navigation style that uses a split view on larger devices and a stack view on smaller devices.
        case split
        /// A navigation style that uses a stack view.
        case stack
        /// The default navigation style.
        ///
        /// On iOS 26+, always uses `split`, relying on the split view's own adaptivity to collapse
        /// to a single column when space is tight. Below iOS 26, uses `split` on iPad and `stack`
        /// everywhere else. Always uses `stack` on tvOS and visionOS, regardless of OS version.
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

    /// The body of the view.
    public var body: some View {
        MessageCenterAdaptiveNavigationView(
            controller: controller,
            predicate: self.predicate,
            navigationStyle: self.navigationStyle
        )
    }
}

/// Owns the list state so it outlives the navigation container.
///
/// With `.auto`, which container we use follows the available width, so an ordinary rotation or
/// window resize can swap a split view for a stack. That tears the container down -- and with it any
/// state it owned, which used to include the list view model and the edit mode. Losing the view
/// model silently discarded a multi-select in progress and re-triggered a load; losing edit mode
/// alone would leave a selection the user could no longer see. This view's identity does not depend
/// on `useSplit`, so state kept here survives the swap.
///
/// `List` scroll offset is still lost, since that belongs to SwiftUI rather than to us.
@MainActor
private struct MessageCenterAdaptiveNavigationView: View {

    @ObservedObject
    private var controller: MessageCenterController

    private let navigationStyle: MessageCenterView.NavigationStyle

    @StateObject
    private var listViewModel: MessageCenterMessageListViewModel

#if !os(macOS)
    @State
    private var editMode: EditMode = .inactive
#endif

    private var shouldUseSplit: Bool {
        switch navigationStyle {
        case .split:
            return true
        case .stack:
            return false
        case .auto:
#if os(tvOS)
            // NavigationSplitView's column layout doesn't pair well with tvOS's remote/focus-driven
            // navigation -- there's no reliable way to move focus into the sidebar and back out.
            // Always use the stack until that's addressed.
            return false
#elseif os(visionOS)
            // NavigationSplitView's own compact-collapse picks the wrong column here, making the
            // list hard to get to. horizontalSizeClass doesn't vary on visionOS, so there's no
            // signal to drive the swap ourselves either. Always use the stack until that's addressed.
            return false
#elseif os(iOS)
            // Before iOS 26, idiom reliably told us whether a split view would fit: phones ran
            // phone-sized, iPads ran iPad-sized. From iOS 26 that's no longer true -- an iPhone-idiom
            // app can run resizable on iPad or in iPhone Mirroring, so a phone can get an iPad's
            // worth of space. On 26+ we lean on NavigationSplitView's own adaptivity (it collapses to
            // a single column when space is tight) rather than trying to predict it ourselves.
            if #available(iOS 26.0, *) {
                return true
            }
            return UIDevice.current.userInterfaceIdiom == .pad
#elseif canImport(UIKit)
            return UIDevice.current.userInterfaceIdiom == .pad
#else
            return true // fallback for macOS, etc.
#endif
        }
    }

    init(
        controller: MessageCenterController,
        predicate: (any MessageCenterPredicate)?,
        navigationStyle: MessageCenterView.NavigationStyle
    ) {
        self.controller = controller
        self.navigationStyle = navigationStyle
        self._listViewModel = .init(wrappedValue: .init(predicate: predicate))
    }

    var body: some View {
        Group {
            if shouldUseSplit {
#if !os(macOS)
                MessageCenterNavigationSplitView(
                    controller: controller,
                    listViewModel: listViewModel,
                    editMode: $editMode
                )
#else
                MessageCenterNavigationSplitView(
                    controller: controller,
                    listViewModel: listViewModel
                )
#endif
            } else {
#if !os(macOS)
                MessageCenterNavigationStack(
                    controller: controller,
                    listViewModel: listViewModel,
                    editMode: $editMode
                )
#else
                MessageCenterNavigationStack(
                    controller: controller,
                    listViewModel: listViewModel
                )
#endif
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

#if canImport(UIKit)
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
#endif
