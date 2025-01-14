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
}
    
