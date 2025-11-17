/* Copyright Airship and Contributors */

#if !os(watchOS)

import Foundation
public import SwiftUI

/// A factory for creating display targets that manage the presentation of views in windows.
///
/// `AirshipDisplayTarget` provides a unified interface for displaying content as either
/// banners or modals. It abstracts the window management logic and provides appropriate
/// display implementations based on the requested display type.
///
/// ## Usage
///
/// ```swift
/// let displayTarget = AirshipDisplayTarget { scene in
///     return scene
/// }
///
/// let displayable = displayTarget.prepareDisplay(for: .modal)
/// try displayable.display { windowInfo in
///     let viewController = MyViewController()
///     return viewController
/// }
/// ```
///
/// - Note: for internal use only.  :nodoc:
@MainActor
public final class AirshipDisplayTarget {

    /// Information about the window where content will be displayed.
    ///
    /// This struct provides metadata about the target window, such as its size,
    /// which can be used to configure the view controller appropriately.
    public struct WindowInfo: Sendable {
        /// The size of the window in points.
        public var size: CGSize
    }

    /// A protocol for objects that can display and dismiss view controllers.
    ///
    /// Implementations of this protocol handle the lifecycle of displaying content
    /// in a window, including creating the appropriate window hierarchy and managing
    /// the view controller's presentation.
    @MainActor
    public protocol Displayable: AnyObject, Sendable {
        /// Displays a view controller provided by the given closure.
        ///
        /// - Parameter viewControllerProvider: A closure that creates and returns
        ///   a view controller to display. The closure receives `WindowInfo` containing
        ///   information about the target window.
        /// - Throws: An error if the view controller cannot be displayed (e.g., if
        ///   a window cannot be found or created).
        func display(viewControllerProvider: @MainActor (WindowInfo) -> UIViewController) throws
        
        /// Dismisses the currently displayed view controller and cleans up resources.
        ///
        /// This method should be called when the displayed content should be removed
        /// from the screen. It handles animation and cleanup of the window hierarchy.
        func dismiss()
    }

    /// The type of display presentation.
    ///
    /// Different display types have different behaviors:
    /// - `.banner`: Displays content as an overlay on top of existing content
    /// - `.modal`: Displays content in a new window that appears above all other content
    public enum DisplayType {
        /// Banner display that overlays on top of existing content.
        case banner
        /// Modal display that appears in a new window above all other content.
        case modal
    }

    /// A closure that provides the `UIWindowScene` to use for displaying content.
    ///
    /// This closure is called when a display operation needs to determine which
    /// window scene to use. It should return the appropriate scene or throw an error
    /// if no scene is available.
    public let sceneProvider: @MainActor () throws -> UIWindowScene

    /// Creates a new display target with the given scene provider.
    ///
    /// - Parameter sceneProvider: A closure that returns the `UIWindowScene` to use
    ///   for displaying content. The closure may throw if no scene is available.
    public init(
        sceneProvider: @escaping @MainActor () throws -> UIWindowScene = { try AirshipSceneManager.shared.lastActiveScene }
    ) {
        self.sceneProvider = sceneProvider
    }

    /// Prepares a displayable object for the specified display type.
    ///
    /// This method creates and returns an appropriate `Displayable` implementation
    /// based on the requested display type. The returned object can then be used to
    /// display view controllers.
    ///
    /// - Parameter displayType: The type of display to prepare (`.banner` or `.modal`).
    /// - Returns: A `Displayable` instance configured for the specified display type.
    public func prepareDisplay(for displayType: DisplayType) -> any Displayable {
        return switch(displayType) {
        case .banner:
            BannerDisplayable(sceneProvider: sceneProvider)
        case .modal:
            ModalDisplayable(sceneProvider: sceneProvider)
        }
    }
}

@MainActor
class ModalDisplayable: AirshipDisplayTarget.Displayable {

    private let sceneProvider: @MainActor () throws -> UIWindowScene
    private var window: UIWindow?

    init(sceneProvider: @escaping @MainActor () throws -> UIWindowScene) {
        self.sceneProvider = sceneProvider
    }

    func display(viewControllerProvider: @MainActor (AirshipDisplayTarget.WindowInfo) -> UIViewController) throws {
        self.dismiss()
        let scene = try sceneProvider()
        let window: UIWindow = UIWindow.airshipMakeModalReadyWindow(scene: scene)
        self.window = window

        let viewController = viewControllerProvider(window.airshipInfo)
        window.rootViewController = viewController
        window.airshipAnimateIn()
    }

    func dismiss() {
        window?.airshipAnimateOut()
        window = nil
    }
}

@MainActor
class BannerDisplayable: AirshipDisplayTarget.Displayable {
    private let sceneProvider: @MainActor () throws -> UIWindowScene
    private let holder: AirshipStrongValueHolder<UIViewController> = AirshipStrongValueHolder()

    init(sceneProvider: @escaping @MainActor () throws -> UIWindowScene) {
        self.sceneProvider = sceneProvider
    }

    func display(viewControllerProvider: @MainActor (AirshipDisplayTarget.WindowInfo) -> UIViewController) throws {
        self.dismiss()
        let scene = try sceneProvider()

        guard let window = AirshipUtils.mainWindow(scene: scene) else {
            throw AirshipErrors.error("Failed to find window")
        }

        guard window.rootViewController != nil else {
            throw AirshipErrors.error("Window missing rootViewController")
        }

        let viewController = viewControllerProvider(window.airshipInfo)
        holder.value = viewController

        if let view = viewController.view {
            view.willMove(toWindow: window)
            window.addSubview(view)
            view.didMoveToWindow()
        }
    }

    func dismiss() {
        holder.value?.view.removeFromSuperview()
        holder.value?.removeFromParent()
        holder.value = nil
    }
}


extension UIWindow {
    /// Returns window information suitable for use with `AirshipDisplayTarget`.
    ///
    /// This property provides a `WindowInfo` struct containing metadata about
    /// the window, such as its size. The size is calculated based on the platform:
    /// - iOS/tvOS: Uses the screen bounds
    /// - visionOS: Uses a standard window size (1280x720) per Apple's guidelines
    /// - watchOS: Uses the device's screen bounds
    var airshipInfo: AirshipDisplayTarget.WindowInfo {
        return .init(size: Self.windowSize(self))
    }

    /// Calculates the appropriate window size for the given window.
    ///
    /// The size calculation varies by platform to account for different
    /// display characteristics and guidelines.
    ///
    /// - Parameter window: The window to calculate the size for.
    /// - Returns: The size of the window in points.
    @MainActor
    private class func windowSize(_ window: UIWindow) -> CGSize {
        #if os(iOS) || os(tvOS)
        return window.screen.bounds.size
        #elseif os(visionOS)
        // https://developer.apple.com/design/human-interface-guidelines/windows#visionOS
        return CGSize(
            width: 1280,
            height: 720
        )
        #elseif os(watchOS)
        return CGSize(
            width: WKInterfaceDevice.current().screenBounds.width,
            height: WKInterfaceDevice.current().screenBounds.height
        )
        #endif
    }

    static func airshipMakeModalReadyWindow(
        scene: UIWindowScene
    ) -> UIWindow {
        let window: UIWindow = AirshipWindowFactory.shared.makeWindow(windowScene: scene)
        window.accessibilityViewIsModal = true
        window.alpha = 0
        window.makeKeyAndVisible()
        window.isUserInteractionEnabled = false

        return window
    }

    func airshipAnimateIn() {
        self.makeKeyAndVisible()
        self.isUserInteractionEnabled = true

        UIView.animate(
            withDuration: 0.3,
            animations: {
                self.alpha = 1
            },
            completion: { _ in
            }
        )
    }

    func airshipAnimateOut() {
        UIView.animate(
            withDuration: 0.3,
            animations: {
                self.alpha = 0
            },
            completion: { _ in
                self.isHidden = true
                self.isUserInteractionEnabled = false
                self.removeFromSuperview()
            }
        )
    }
}

#endif
