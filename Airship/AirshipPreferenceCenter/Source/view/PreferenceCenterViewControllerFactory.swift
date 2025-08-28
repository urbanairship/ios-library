/* Copyright Airship and Contributors */


import SwiftUI
public import UIKit

/// View factories for Preference Center view controllers
public class PreferenceCenterViewControllerFactory: NSObject {
        
    /// Makes a view controller for the given Preference Center ID.
    /// - Parameters:
    ///     - preferenceCenterID: The preferenceCenterID.
    ///     - dismissAction: Optional action to dismiss the view controller.
    /// - Returns: A view controller.
    @MainActor
    public class func makeViewController(
        preferenceCenterID: String,
        dismissAction: (@Sendable () -> Void)? = nil
    )-> UIViewController {
        let view = PreferenceCenterView(preferenceCenterID: preferenceCenterID)
        return makeViewController(
            view: view,
            preferenceCenterTheme: nil,
            dismissAction: dismissAction
        )
    }

    /// Makes a view controller for the given Preference Center ID and theme.
    /// - Parameters:
    ///     - preferenceCenterID: The preferenceCenterID.
    ///     - preferenceCenterThemePlist: The theme plist.
    /// - Returns: A view controller.
    @MainActor
    public class func makeViewController(
        preferenceCenterID: String,
        preferenceCenterThemePlist: String
    ) throws -> UIViewController {

        let theme = try PreferenceCenterThemeLoader.fromPlist(
            preferenceCenterThemePlist
        )
        return makeViewController(
            preferenceCenterID: preferenceCenterID,
            preferenceCenterTheme: theme
        )
    }

    /// Makes a view controller for the given Preference Center ID and theme.
    /// - Parameters:
    ///     - preferenceCenterID: The preferenceCenterID.
    ///     - preferenceCenterTheme: The theme.
    ///     - dismissAction: Optional action to dismiss the view controller.
    /// - Returns: A view controller.
    @MainActor
    public class func makeViewController(
        preferenceCenterID: String,
        preferenceCenterTheme: PreferenceCenterTheme? = nil,
        dismissAction: (@Sendable () -> Void)? = nil
    ) -> UIViewController {
        let view = PreferenceCenterView(preferenceCenterID: preferenceCenterID)
        return makeViewController(
            view: view,
            preferenceCenterTheme: preferenceCenterTheme,
            dismissAction: dismissAction
        )
    }

    /// Makes a view controller for the given view  and theme.
    /// - Parameters:
    ///     - preferenceCenterID: The Preference Center view.
    ///     - preferenceCenterTheme: The theme.
    ///     - dismissAction: Optional action to dismiss the view controller.
    /// - Returns: A view controller.
    @MainActor
    public class func makeViewController(
        view: PreferenceCenterView,
        preferenceCenterTheme: PreferenceCenterTheme?,
        dismissAction: (@MainActor @Sendable () -> Void)? = nil
    ) -> UIViewController {
        let theme = preferenceCenterTheme ?? PreferenceCenterTheme()
    
        let isLight = UITraitCollection.current.userInterfaceStyle == .light

        let resolvedBackgroundColor = isLight ? theme.viewController?.backgroundColor : theme.viewController?.backgroundColorDark

        return PreferenceCenterViewController(
            rootView: view
                .preferenceCenterTheme(theme)
                .addPreferenceCenterDismissAction(
                    action: dismissAction
                ),
            backgroundColor: resolvedBackgroundColor
        )
    }
}

private class PreferenceCenterViewController<Content>: UIHostingController<Content> where Content: View {
    init(
        rootView: Content,
        backgroundColor: UIColor? = nil
    ) {
        super.init(rootView: rootView)
        if let backgroundColor = backgroundColor {
            self.view.backgroundColor = backgroundColor
        }
    }

    required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
