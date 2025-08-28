/* Copyright Airship and Contributors */


public import UIKit

/// Scene delegate
public protocol InAppMessageSceneDelegate: AnyObject {

    /// Called to get the scene for a given message. If no scene is provided, the default scene will be used.
    /// - Parameters:
    ///     - message: The in-app message
    /// - Returns: A UIWindowScene
    @MainActor
    func sceneForMessage(_ message: InAppMessage) -> UIWindowScene?
}
