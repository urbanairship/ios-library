/* Copyright Airship and Contributors */

#if canImport(UIKit) && !os(watchOS)

import UIKit

/// A singleton factory class to create and configure UIWindow objects.
/// This allows apps to override behaviors like dark mode and other window-specific settings.
@MainActor
public final class AirshipWindowFactory {

    /// The shared instance of `AirshipWindowFactory` for centralized window creation.
    public static let shared: AirshipWindowFactory = AirshipWindowFactory()

    /// A closure that allows apps to customize window creation.
    /// If nil, the default window creation behavior will be used.
    public var makeBlock: (@MainActor @Sendable (UIWindowScene) -> UIWindow)?

    private init() {}

    /// Creates a new UIWindow for the given window scene.
    ///
    /// - Parameter windowScene: The `UIWindowScene` in which the new window will be created.
    /// - Returns: A `UIWindow` object configured for the given `UIWindowScene`.
    public func makeWindow(windowScene: UIWindowScene) -> UIWindow {
        return makeBlock?(windowScene) ?? UIWindow(windowScene: windowScene)
    }
}

#endif
