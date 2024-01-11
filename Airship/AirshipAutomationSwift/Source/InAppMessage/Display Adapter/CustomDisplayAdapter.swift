/* Copyright Airship and Contributors */

import Foundation
import UIKit

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
    ///
    // TODO: Return a resolution info
    @MainActor
    func display(scene: UIWindowScene) async
}


