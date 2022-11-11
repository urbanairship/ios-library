/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import UIKit

/// View factories for Preference Center view controllers
@objc(UAPreferenceCenterViewControllerFactory)
public class PreferenceCenterViewControllerFactory: NSObject {

    /// Makes a view controller for the given Preference Center ID.
    /// - Parameters:
    ///     - preferenceCenterID: The preferenceCenterID.
    /// - Returns: A view controller.
    @objc
    public class func makeViewController(preferenceCenterID: String)
        -> UIViewController
    {
        let view = PreferenceCenterView(preferenceCenterID: preferenceCenterID)
        return makeViewController(
            view: view,
            preferenceCenterTheme: nil
        )
    }

    /// Makes a view controller for the given Preference Center ID and theme.
    /// - Parameters:
    ///     - preferenceCenterID: The preferenceCenterID.
    ///     - preferenceCenterThemePlist: The theme plist.
    /// - Returns: A view controller.
    @objc
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
    /// - Returns: A view controller.
    public class func makeViewController(
        preferenceCenterID: String,
        preferenceCenterTheme: PreferenceCenterTheme
    ) -> UIViewController {
        let view = PreferenceCenterView(preferenceCenterID: preferenceCenterID)
        return makeViewController(
            view: view,
            preferenceCenterTheme: preferenceCenterTheme
        )
    }

    /// Makes a view controller for the given view  and theme.
    /// - Parameters:
    ///     - preferenceCenterID: The Preference Center view.
    ///     - preferenceCenterTheme: The theme.
    /// - Returns: A view controller.
    public class func makeViewController(
        view: PreferenceCenterView,
        preferenceCenterTheme: PreferenceCenterTheme?
    ) -> UIViewController {

        let theme = preferenceCenterTheme ?? PreferenceCenterTheme()
        return PreferenceCenterViewController(
            rootView: view.preferenceCenterTheme(theme),
            backgroundColor: theme.viewController?.backgroundColor
        )
    }
}

private class PreferenceCenterViewController<Content>: UIHostingController<
    Content
>
where Content: View {
    init(
        rootView: Content,
        backgroundColor: UIColor? = nil
    ) {
        super.init(rootView: rootView)
        if let backgroundColor = backgroundColor {
            self.view.backgroundColor = backgroundColor
        }
    }

    @objc
    required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
