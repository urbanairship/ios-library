/* Copyright Airship and Contributors */

import Foundation
import AirshipBasement

#if canImport(UIKit)
public import UIKit
#elseif canImport(AppKit)
public import AppKit
#endif

/// Cross-platform carrier for the window scene values a layout needs, read by the host at
/// display time. Views never touch `UIWindowScene` APIs directly, and no platform-specific type
/// leaks into call-site signatures on platforms that have no window scene.
/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public struct ThomasWindowScene: Sendable {
    /// Status bar content style of the scene when the layout was displayed.
    enum StatusBarStyle: Sendable {
        case `default`
        case lightContent
        case darkContent
    }

    /// Read once at init: querying `UIStatusBarManager` from a view body can re-enter the
    /// SwiftUI graph mid-update and abort. https://github.com/urbanairship/ios-library/issues/470
    let statusBarStyle: StatusBarStyle?

    public init() {
        self.statusBarStyle = nil
    }
}

#if !os(tvOS) && !os(watchOS) && !os(macOS)
extension ThomasWindowScene {
    @MainActor
    public init(_ scene: UIWindowScene?) {
        self.statusBarStyle = scene?.statusBarManager.map { StatusBarStyle($0.statusBarStyle) }
    }
}

extension ThomasWindowScene.StatusBarStyle {
    init(_ style: UIStatusBarStyle) {
        switch style {
        case .default: self = .default
        case .darkContent: self = .darkContent
        case .lightContent: self = .lightContent
        @unknown default: self = .default
        }
    }
}
#endif

#if !os(watchOS) && !os(macOS)
extension UIWindowScene {
    /// The space actually available to this scene's windows.
    ///
    /// A scene does not necessarily fill its screen. On iPad, in iPhone Mirroring, and from
    /// iOS 27 on for any resizable app, it occupies an arbitrary slice of the display that the
    /// user can change at any time, so screen bounds do not describe what we are able to draw
    /// into. Prefer the scene's own resolved geometry, then its first visible window, and only
    /// fall back to the screen when neither has been laid out yet.
    @MainActor
    var airshipAvailableSpace: CGSize {
        if #available(iOS 26.0, tvOS 26.0, visionOS 26.0, *) {
            let bounds = self.effectiveGeometry.coordinateSpace.bounds
            if !bounds.isEmpty {
                return bounds.size
            }
        }

        if let window = self.windows.first(where: { !$0.isHidden }), !window.bounds.isEmpty {
            return window.bounds.size
        }

#if os(visionOS)
        // https://developer.apple.com/design/human-interface-guidelines/windows#visionOS
        return CGSize(width: 1280, height: 720)
#else
        return self.screen.bounds.size
#endif
    }
}
#endif
