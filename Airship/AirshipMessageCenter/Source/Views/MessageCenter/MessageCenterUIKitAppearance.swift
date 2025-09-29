/* Copyright Airship and Contributors */

import SwiftUI
import UIKit

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Detects and bridges UIKit navigation appearance to SwiftUI Message Center
internal struct MessageCenterUIKitAppearance {

    // MARK: - Appearance Data Model

    /// Captured UIKit appearance data
    struct DetectedAppearance: Equatable {
        var navigationBarTintColor: Color?
        var navigationBarBackgroundColor: Color?
        var navigationTitleColor: Color?
        var navigationTitleFont: Font?
        var navigationLargeTitleColor: Color?
        var navigationLargeTitleFont: Font?
        var navigationBarIsTranslucent: Bool = true
        var prefersLargeTitles: Bool = false
        var navigationTitle: String?

        static func == (lhs: DetectedAppearance, rhs: DetectedAppearance) -> Bool {
            // Compare all properties except fonts (Font doesn't conform to Equatable)
            return lhs.navigationBarTintColor == rhs.navigationBarTintColor &&
            lhs.navigationBarBackgroundColor == rhs.navigationBarBackgroundColor &&
            lhs.navigationTitleColor == rhs.navigationTitleColor &&
            lhs.navigationLargeTitleColor == rhs.navigationLargeTitleColor &&
            lhs.navigationBarIsTranslucent == rhs.navigationBarIsTranslucent &&
            lhs.prefersLargeTitles == rhs.prefersLargeTitles &&
            lhs.navigationTitle == rhs.navigationTitle
        }

        // Convert UIKit appearance to this model
        @MainActor
        static func from(navigationBar: UINavigationBar?, navigationItem: UINavigationItem?) -> DetectedAppearance {
            var appearance = DetectedAppearance()

            // Extract tint color (affects back buttons and bar button items)
            if let tintColor = navigationBar?.tintColor {
                appearance.navigationBarTintColor = Color(tintColor)
            }

            // Prioritize navigation item's appearance over navigation bar's appearance
            let standardAppearance = navigationItem?.standardAppearance ?? navigationBar?.standardAppearance

            // Extract from standard appearance
            if let standardAppearance = standardAppearance {
                // Background color
                if let backgroundColor = standardAppearance.backgroundColor {
                    appearance.navigationBarBackgroundColor = Color(backgroundColor)
                }

                // Title attributes
                if let titleColor = standardAppearance.titleTextAttributes[.foregroundColor] as? UIColor {
                    appearance.navigationTitleColor = Color(titleColor)
                }
                if let titleFont = standardAppearance.titleTextAttributes[.font] as? UIFont {
                    appearance.navigationTitleFont = Font(titleFont)
                }

                // Large title attributes
                if let largeTitleColor = standardAppearance.largeTitleTextAttributes[.foregroundColor] as? UIColor {
                    appearance.navigationLargeTitleColor = Color(largeTitleColor)
                }
                if let largeTitleFont = standardAppearance.largeTitleTextAttributes[.font] as? UIFont {
                    appearance.navigationLargeTitleFont = Font(largeTitleFont)
                }
            }

            // Extract other properties
            appearance.navigationBarIsTranslucent = navigationBar?.isTranslucent ?? true
#if !os(tvOS)
            appearance.prefersLargeTitles = navigationBar?.prefersLargeTitles ?? false
#endif
            // Extract title from navigation item
            appearance.navigationTitle = navigationItem?.title

            return appearance
        }
    }

    // MARK: - Environment Keys

    struct DetectedAppearanceKey: EnvironmentKey {
        static let defaultValue: DetectedAppearance? = nil
    }

    // MARK: - Weak Reference Wrapper

    /// Weak reference wrapper to prevent retain cycles
    final class WeakReference<T: AnyObject> {
        weak var value: T?

        init(_ value: T?) {
            self.value = value
        }
    }
}

// MARK: - Environment Extensions

extension EnvironmentValues {
    /// The detected UIKit appearance from parent navigation
    var messageCenterDetectedAppearance: MessageCenterUIKitAppearance.DetectedAppearance? {
        get { self[MessageCenterUIKitAppearance.DetectedAppearanceKey.self] }
        set { self[MessageCenterUIKitAppearance.DetectedAppearanceKey.self] = newValue }
    }
}

// MARK: - Effective Colors Helper

internal struct MessageCenterEffectiveColors {
    let detectedAppearance: MessageCenterUIKitAppearance.DetectedAppearance?
    let theme: MessageCenterTheme
    let colorScheme: ColorScheme

    private func resolveButtonColor(themeLight: Color?, themeDark: Color?) -> Color? {
        detectedAppearance?.navigationBarTintColor ?? colorScheme.airshipResolveColor(
            light: themeLight,
            dark: themeDark
        )
    }

    var navigationBarTintColor: Color? {
        detectedAppearance?.navigationBarTintColor
    }

    var backButtonColor: Color? {
        resolveButtonColor(themeLight: theme.backButtonColor, themeDark: theme.backButtonColorDark)
    }

    var deleteButtonColor: Color? {
        resolveButtonColor(themeLight: theme.deleteButtonTitleColor, themeDark: theme.deleteButtonTitleColorDark)
    }

    var editButtonColor: Color? {
        resolveButtonColor(themeLight: theme.editButtonTitleColor, themeDark: theme.editButtonTitleColorDark)
    }

    var navigationBarBackgroundColor: Color? {
        detectedAppearance?.navigationBarBackgroundColor ?? colorScheme.airshipResolveColor(
            light: theme.messageListContainerBackgroundColor,
            dark: theme.messageListContainerBackgroundColorDark
        )
    }

    var navigationTitleColor: Color? {
        detectedAppearance?.navigationTitleColor
    }
}

// MARK: - Appearance Detector View

internal struct MessageCenterAppearanceDetector: UIViewRepresentable {
    @Binding var detectedAppearance: MessageCenterUIKitAppearance.DetectedAppearance?
    let hostingControllerRef: MessageCenterUIKitAppearance.WeakReference<UIViewController>

    func makeUIView(context: Context) -> UIView {
        let view = IntrospectionView()
        view.onAppearanceDetected = { appearance in
            DispatchQueue.main.async {
                self.detectedAppearance = appearance
            }
        }
        view.hostingControllerRef = hostingControllerRef
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let introspectionView = uiView as? IntrospectionView {
            introspectionView.detectAppearance()
        }
    }

    class IntrospectionView: UIView {
        var onAppearanceDetected: ((MessageCenterUIKitAppearance.DetectedAppearance) -> Void)?
        var hostingControllerRef: MessageCenterUIKitAppearance.WeakReference<UIViewController>?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil {
                detectAppearance()
            }
        }

        @MainActor
        func detectAppearance() {
            guard let hostingController = hostingControllerRef?.value,
                  let navController = hostingController.navigationController else {
                return
            }

            let appearance = MessageCenterUIKitAppearance.DetectedAppearance.from(
                navigationBar: navController.navigationBar,
                navigationItem: hostingController.navigationItem
            )

            onAppearanceDetected?(appearance)
        }
    }
}

// MARK: - View Modifier for Applying Detected Appearance

internal struct MessageCenterApplyDetectedAppearance: ViewModifier {
    @Environment(\.messageCenterDetectedAppearance) var detectedAppearance

    func body(content: Content) -> some View {
        if let appearance = detectedAppearance {
            content
                .airshipApplyIf(appearance.navigationBarTintColor != nil) { view in
                    // Apply navigation bar tint color (affects back button and bar items)
                    view.accentColor(appearance.navigationBarTintColor)
                        .tint(appearance.navigationBarTintColor)
                }
                .airshipApplyIf(appearance.navigationBarBackgroundColor != nil) { view in
                    // Apply navigation bar background color
                    view.toolbarBackground(appearance.navigationBarBackgroundColor!, for: .navigationBar)
                        .toolbarBackground(.visible, for: .navigationBar)
                }
#if !os(tvOS)
                .navigationBarTitleDisplayMode(appearance.prefersLargeTitles ? .large : .inline)
#endif
        } else {
            content
        }
    }
}

// MARK: - Helper Extensions

extension Font {
    /// Initialize Font from UIFont
    init(_ uiFont: UIFont) {
        self = Font(uiFont as CTFont)
    }
}

// MARK: - View Extension for Appearance

extension View {
    /// Detects UIKit navigation appearance and applies it to Message Center
    func applyUIKitNavigationAppearance() -> some View {
        self.modifier(MessageCenterApplyDetectedAppearance())
    }
}
