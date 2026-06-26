/* Copyright Airship and Contributors */

import Foundation
import AirshipBasement

#if canImport(UIKit)
public import UIKit
#elseif canImport(AppKit)
public import AppKit
#endif

/// Cross-platform carrier for the window scene a layout is presented in, captured by the
/// host at display time. Holds the scene weakly and exposes only the values the renderer
/// needs, so views never touch `UIWindowScene` APIs directly and no platform-specific type
/// leaks into call-site signatures on platforms that have no window scene.
/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public struct ThomasWindowScene {
#if !os(tvOS) && !os(watchOS) && !os(macOS)
    private weak var scene: UIWindowScene?

    public init(_ scene: UIWindowScene?) {
        self.scene = scene
    }

    /// Status bar content style of the captured scene, if any.
    @MainActor
    var statusBarStyle: UIStatusBarStyle? {
        scene?.statusBarManager?.statusBarStyle
    }
#endif

    public init() {}

    /// Interface orientation to render at. Derived from the captured scene where one exists,
    /// and a fixed value on platforms without interface orientation.
    @MainActor
    var orientation: ThomasOrientation {
#if os(tvOS) || os(watchOS) || os(macOS)
        return .landscape
#else
        guard let scene else { return .portrait }
        if scene.interfaceOrientation.isLandscape {
            return .landscape
        } else if scene.interfaceOrientation.isPortrait {
            return .portrait
        }
        return .portrait
#endif
    }
}
