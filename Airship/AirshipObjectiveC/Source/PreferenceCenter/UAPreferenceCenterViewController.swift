/* Copyright Airship and Contributors */

public import Foundation
public import UIKit

#if canImport(AirshipCore)
import AirshipPreferenceCenter
import AirshipCore
import SwiftUICore
#endif

/// Preference Center view controller factory
@objc
public final class UAPreferenceCenterViewControllerFactory: NSObject, Sendable {
    
    @objc
    /// Makes a view controller for the given Preference Center ID.
    /// - Parameters:
    ///     - preferenceCenterID: The preferenceCenterID.
    /// - Returns: A view controller.
    @MainActor
    public class func makeViewController(
        preferenceCenterID: String
    )-> UIViewController {
        return PreferenceCenterViewControllerFactory.makeViewController(preferenceCenterID: preferenceCenterID)
    }

    @objc
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
        return try PreferenceCenterViewControllerFactory.makeViewController(preferenceCenterID: preferenceCenterID, preferenceCenterThemePlist: preferenceCenterThemePlist)
    }

    @objc
    /// Embeds the preference center view in another view.
    /// - Parameters:
    ///   - preferenceCenterID: The preference center ID.
    ///   - preferenceCenterThemePlist: Optional path to a theme plist.
    ///   - parentViewController: The parent view controller into which we'll embed the preference center.
    /// - Returns: A UIView to be added into another view.
    @MainActor
    public class func embed(
        preferenceCenterID: String,
        preferenceCenterThemePlist: String? = nil,
        in parentViewController: UIViewController
    ) throws -> UIView {
        let childVC: UIViewController
        if let themePlist = preferenceCenterThemePlist {
            childVC = try makeViewController(preferenceCenterID: preferenceCenterID, preferenceCenterThemePlist: themePlist)
        } else {
            childVC = makeViewController(preferenceCenterID: preferenceCenterID)
        }

        parentViewController.addChild(childVC)

        let containerView = UIView(frame: .zero)
        containerView.addSubview(childVC.view)
        childVC.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            childVC.view.topAnchor.constraint(equalTo: containerView.topAnchor),
            childVC.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            childVC.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            childVC.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        childVC.didMove(toParent: parentViewController)

        return containerView
    }
}
    
