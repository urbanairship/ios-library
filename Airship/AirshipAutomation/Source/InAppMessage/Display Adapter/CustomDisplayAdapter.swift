/* Copyright Airship and Contributors */

import Foundation
public import UIKit

#if canImport(AirshipCore)
import AirshipCore
#endif


/// Custom display adapter types
public enum CustomDisplayAdapterType: Sendable {
    /// HTML adapter
    case html
    
    /// Modal adapter
    case modal

    /// Fullscreen adapter
    case fullscreen

    /// Banner adapter
    case banner

    /// Custom adapapter
    case custom
}

/// Custom display adapter
public protocol CustomDisplayAdapter: Sendable {
    /// Checks if the adapter is ready
    @MainActor
    var isReady: Bool { get }

    @MainActor
    func waitForReady() async

    /// Called to display the message
    /// - Parameters:
    ///     - scene: The window scene
    /// - Returns a CustomDisplayResolution
    @MainActor
    func display(scene: UIWindowScene) async -> CustomDisplayResolution
}

/// Resolution data
public enum CustomDisplayResolution {
    /// Button tap
    case buttonTap(InAppMessageButtonInfo)
    /// Message tap
    case messageTap
    /// User dismissed
    case userDismissed
    /// Timed out
    case timedOut
}

