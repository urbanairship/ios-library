/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

#if canImport(AirshipCore)
public import AirshipCore
#endif

#if canImport(UIKit)
public import UIKit
#endif

#if canImport(AppKit)
public import AppKit
#endif

/// View factories for Preference Center view controllers.
///
/// This factory provides a unified way to create native view controllers (`UIViewController` on iOS/tvOS
/// or `NSViewController` on macOS) that host a Preference Center SwiftUI view.
public class PreferenceCenterViewControllerFactory: NSObject {

    /// Makes a view controller for the given Preference Center ID.
    /// - Parameters:
    ///   - preferenceCenterID: The preference center identifier.
    ///   - dismissAction: Optional action to be executed when the Preference Center is dismissed.
    /// - Returns: A native view controller hosting the Preference Center.
    @MainActor
    public class func makeViewController(
        preferenceCenterID: String,
        dismissAction: (@Sendable () -> Void)? = nil
    ) -> AirshipNativeViewController {
        makeViewController(
            view: PreferenceCenterView(preferenceCenterID: preferenceCenterID),
            preferenceCenterTheme: nil,
            dismissAction: dismissAction
        )
    }

    /// Makes a view controller for the given Preference Center ID and theme plist.
    /// - Parameters:
    ///   - preferenceCenterID: The preference center identifier.
    ///   - preferenceCenterThemePlist: The name of the plist file containing the theme configuration.
    /// - Returns: A native view controller hosting the Preference Center.
    /// - Throws: An error if the theme plist could not be loaded.
    @MainActor
    public class func makeViewController(
        preferenceCenterID: String,
        preferenceCenterThemePlist: String
    ) throws -> AirshipNativeViewController {
        let theme = try PreferenceCenterThemeLoader.fromPlist(preferenceCenterThemePlist)
        return makeViewController(
            preferenceCenterID: preferenceCenterID,
            preferenceCenterTheme: theme
        )
    }

    /// Makes a view controller for the given Preference Center ID and optional theme.
    /// - Parameters:
    ///   - preferenceCenterID: The preference center identifier.
    ///   - preferenceCenterTheme: An optional `PreferenceCenterTheme` to style the view.
    ///   - dismissAction: Optional action to be executed when the Preference Center is dismissed.
    /// - Returns: A native view controller hosting the Preference Center.
    @MainActor
    public class func makeViewController(
        preferenceCenterID: String,
        preferenceCenterTheme: PreferenceCenterTheme? = nil,
        dismissAction: (@Sendable () -> Void)? = nil
    ) -> AirshipNativeViewController {
        makeViewController(
            view: PreferenceCenterView(preferenceCenterID: preferenceCenterID),
            preferenceCenterTheme: preferenceCenterTheme,
            dismissAction: dismissAction
        )
    }

    /// Makes a view controller for a specific `PreferenceCenterView` instance and theme.
    /// - Parameters:
    ///   - view: The `PreferenceCenterView` to host.
    ///   - preferenceCenterTheme: The theme configuration.
    ///   - dismissAction: Optional action to be executed when the Preference Center is dismissed.
    /// - Returns: A native view controller hosting the Preference Center.
    @MainActor
    public class func makeViewController(
        view: PreferenceCenterView,
        preferenceCenterTheme: PreferenceCenterTheme?,
        dismissAction: (@MainActor @Sendable () -> Void)? = nil
    ) -> AirshipNativeViewController {
        let theme = preferenceCenterTheme ?? PreferenceCenterTheme()

        #if os(macOS)
        let isDark = NSApp.effectiveAppearance.isDark
        #else
        let isDark = UITraitCollection.current.userInterfaceStyle == .dark
        #endif

        let resolvedBackgroundColor = isDark ? theme.viewController?.backgroundColorDark : theme.viewController?.backgroundColor

        return PreferenceCenterViewController(
            rootView: view
                .preferenceCenterTheme(theme)
                .addPreferenceCenterDismissAction(action: dismissAction),
            backgroundColor: resolvedBackgroundColor
        )
    }
}

/// A platform-specific hosting controller that manages the lifecycle and styling of the Preference Center view.
private class PreferenceCenterViewController<Content>: AirshipNativeHostingController<Content> where Content: View {
    
    /// Initializes the controller.
    /// - Parameters:
    ///   - rootView: The SwiftUI content.
    ///   - backgroundColor: The background color to apply to the underlying native view.
    init(rootView: Content, backgroundColor: AirshipNativeColor? = nil) {
        super.init(rootView: rootView)
        
#if os(macOS)
        // Ensure the view is layer-backed on macOS to support background colors
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = backgroundColor?.cgColor
#else
        if let backgroundColor = backgroundColor {
            self.view.backgroundColor = backgroundColor
        }
#endif
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
