/* Copyright Airship and Contributors */

import Foundation

/// Permissions manager delegate. Allows for extending permission gathering.
public protocol AirshipPermissionDelegate {

    /// Called when a permission needs to be checked.
    /// - Returns: the permission status.
    @MainActor
    func checkPermissionStatus() async -> AirshipPermissionStatus

    /// Called when a permission should be requested.
    ///
    /// - Note: A permission might be already granted when this method is called.
    ///
    /// - Returns: the permission status.
    @MainActor
    func requestPermission() async -> AirshipPermissionStatus
}
