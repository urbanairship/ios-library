/* Copyright Airship and Contributors */

#if !os(watchOS)

#if canImport(AppKit)
public import AppKit
#elseif canImport(UIKit)
public import UIKit
#endif

/// A singleton factory class to create and configure UIWindow objects.
/// This allows apps to override behaviors like dark mode and other window-specific settings.
@MainActor
public final class AirshipWindowFactory: Sendable {

    /// The shared instance of `AirshipWindowFactory` for centralized window creation.
    public static let shared = AirshipWindowFactory()

    private init() {}

#if os(macOS)
    /// A closure that allows apps to customize window creation.
    public var makeBlock: (@MainActor @Sendable () -> NSWindow)?

    /// Creates a new NSWindow.
    public func makeWindow() -> NSWindow {
        return makeBlock?() ?? NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
    }
#else
    /// A closure that allows apps to customize window creation.
    public var makeBlock: (@MainActor @Sendable (UIWindowScene) -> UIWindow)?

    /// Creates a new UIWindow for the given window scene.
    ///
    /// - Parameter windowScene: The `UIWindowScene` in which the new window will be created.
    public func makeWindow(windowScene: UIWindowScene) -> UIWindow {
        return makeBlock?(windowScene) ?? UIWindow(windowScene: windowScene)
    }
#endif
}

#endif
