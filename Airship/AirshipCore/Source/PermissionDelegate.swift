/* Copyright Airship and Contributors */

import Foundation

/// Permissions manager delegate. Allows for extending permission gathering.
@objc(UAAirshipPermissionDelegate)
public protocol AirshipPermissionDelegate {

    /// Called when a permission needs to be checked.
    /// - Parameters:
    ///     - completionHandler: The completion handler
    @objc
    func checkPermissionStatus(
        completionHandler: @escaping (AirshipPermissionStatus) -> Void
    )

    /// Called when a permission should be requested.
    ///
    /// - Note: A permission might be already granted when this method is called.
    ///
    /// - Parameters:
    ///     - completionHandler: The completion handler
    @objc
    func requestPermission(
        completionHandler: @escaping (AirshipPermissionStatus) -> Void
    )
}
