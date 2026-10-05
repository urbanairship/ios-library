/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// The fields every selector can match: placement, color and media URL selectors alike.
///
/// Every field a selector names must hold, a field it leaves out matches anything, and the first
/// selector in a list that matches wins. Each is a value that changes rarely; none measures a size.
protocol ThomasSelectorConditions {
    var platform: ThomasPlatform? { get }
    var darkMode: Bool? { get }
    var windowSize: ThomasWindowSize? { get }
    var orientation: ThomasOrientation? { get }
}

/// The values selectors are matched against, published by `RootView`.
struct ThomasSelectorEnvironment: Equatable, Sendable {
    var darkMode: Bool
    /// `nil` outside a scene's root, where a selector naming a window size doesn't match.
    var windowSize: ThomasWindowSize?
    /// `nil` outside a scene's root, where a selector naming an orientation doesn't match.
    var orientation: ThomasOrientation?
}

extension ThomasSelectorConditions {
    /// Returns whether every field the selector names holds in `environment`.
    ///
    /// - Parameters:
    ///   - environment: what the scene is shown in
    ///   - ignoringOrientation: true to leave the orientation out
    /// - Returns: true where every named field holds
    func matches(_ environment: ThomasSelectorEnvironment, ignoringOrientation: Bool = false) -> Bool {
        (platform == nil || platform == .ios)
            && (darkMode == nil || darkMode == environment.darkMode)
            && (windowSize == nil || windowSize == environment.windowSize)
            && (ignoringOrientation || orientation == nil || orientation == environment.orientation)
    }
}

extension Array where Element: ThomasSelectorConditions {
    /// Returns the first selector that matches `environment`.
    ///
    /// - Parameter environment: what the scene is shown in
    /// - Returns: the first match, or `nil` when none does
    func firstMatch(_ environment: ThomasSelectorEnvironment) -> Element? {
        first { $0.matches(environment) }
    }
}

private struct ThomasSelectorEnvironmentKey: EnvironmentKey {
    static let defaultValue: ThomasSelectorEnvironment = ThomasSelectorEnvironment(darkMode: false)
}

extension EnvironmentValues {
    /// What selectors match against, set by `RootView` for everything inside the scene.
    var thomasSelectorEnvironment: ThomasSelectorEnvironment {
        get { self[ThomasSelectorEnvironmentKey.self] }
        set { self[ThomasSelectorEnvironmentKey.self] = newValue }
    }
}
