/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
@_spi(AirshipInternal) import AirshipBasement

/// The fields every selector can match: placement, color and media URL selectors alike.
///
/// Every field a selector names must hold, a field it leaves out matches anything, and the first
/// selector in a list that matches wins. Each is a value that changes rarely; none measures a size.
protocol ThomasSelectorConditions {
    var platform: ThomasPlatform? { get }
    var darkMode: Bool? { get }
    var windowSize: ThomasWindowSize? { get }
    var orientation: ThomasOrientation? { get }
    /// Environment conditions' chosen values, each of which must equal the one given: `{"size": "compact"}`
    /// matches while the scene's `size` condition has chosen `compact`.
    var environmentConditions: [String: AirshipJSON]? { get }
}

/// The values selectors are matched against, published by `RootView`.
struct ThomasSelectorEnvironment: Equatable, Sendable {
    var darkMode: Bool
    /// `nil` outside a scene's root, where a selector naming a window size doesn't match.
    var windowSize: ThomasWindowSize?
    /// `nil` outside a scene's root, where a selector naming an orientation doesn't match.
    var orientation: ThomasOrientation?
    /// The scene's environment conditions' chosen values; one with none chosen is left out.
    var conditions: [String: AirshipJSON] = [:]
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
            && (environmentConditions ?? [:]).allSatisfy { environment.conditions[$0.key] == $0.value }
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

/// Lengths in points, both ends inclusive, as a JSON predicate's `at_least` and `at_most` are; an omitted end is unbounded.
struct ThomasLengthRange: ThomasSerializable {
    var atLeast: Double?
    var atMost: Double?

    private enum CodingKeys: String, CodingKey {
        case atLeast = "at_least"
        case atMost = "at_most"
    }

    /// Returns whether `range` allows `length`.
    ///
    /// - Parameters:
    ///   - range: the range a selector names, if it names one
    ///   - length: the length, or `nil` where it isn't known
    /// - Returns: true where no range is named, or the length is known and inside it
    static func allows(_ range: ThomasLengthRange?, _ length: CGFloat?) -> Bool {
        guard let range else { return true }
        guard let length = length.map(Double.init) else { return false }
        return (range.atLeast.map { length >= $0 } ?? true) && (range.atMost.map { length <= $0 } ?? true)
    }
}

/// One entry in an environment condition: the shared selector fields, sizes, and the value it chooses.
///
/// A length that isn't known, such as the height of a frame its content sizes, matches no range.
struct ThomasEnvironmentConditionSelector: ThomasSerializable, ThomasSelectorConditions {
    var platform: ThomasPlatform?
    var darkMode: Bool?
    var windowSize: ThomasWindowSize?
    var orientation: ThomasOrientation?
    var windowWidth: ThomasLengthRange?
    var windowHeight: ThomasLengthRange?
    /// The window less its safe-area insets.
    var safeWindowWidth: ThomasLengthRange?
    var safeWindowHeight: ThomasLengthRange?
    /// The space the host gives the scene.
    var frameWidth: ThomasLengthRange?
    var frameHeight: ThomasLengthRange?
    var value: AirshipJSON

    /// A condition can't depend on another's chosen value.
    var environmentConditions: [String: AirshipJSON]? { nil }

    private enum CodingKeys: String, CodingKey {
        case platform
        case darkMode = "dark_mode"
        case windowSize = "window_size"
        case orientation
        case windowWidth = "window_width"
        case windowHeight = "window_height"
        case safeWindowWidth = "safe_window_width"
        case safeWindowHeight = "safe_window_height"
        case frameWidth = "frame_width"
        case frameHeight = "frame_height"
        case value
    }
}

/// One entry in a grid condition: a range on the grid's content width, and the value it chooses.
struct ThomasGridConditionSelector: ThomasSerializable {
    var width: ThomasLengthRange?
    var value: AirshipJSON
}

/// What `$environment` holds beyond the platform's settings.
struct ThomasEnvironmentStateInfo: ThomasSerializable {
    /// Named breakpoints on the window, safe window and frame, read at `$environment.conditions.<name>`
    /// and by selectors' `environment_conditions`.
    var conditions: [String: [ThomasEnvironmentConditionSelector]]?
}

/// What a grid puts in `$grids.current` for the grid, its items and every view inside it.
struct ThomasGridStateInfo: ThomasSerializable {
    /// Named breakpoints on the grid's content width, read at `$grids.current.conditions.<name>`.
    var conditions: [String: [ThomasGridConditionSelector]]?
}

/// Chooses each named condition's value: that of its first selector that matches.
enum ThomasConditions {

    /// Chooses each environment condition's value from the measured environment.
    ///
    /// For example, `size: [{window_width: {at_most: 599}, value: compact}, {value: expanded}]`
    /// chooses `compact` in a 390-wide window and `expanded` in a 1024-wide one.
    ///
    /// - Parameters:
    ///   - conditions: the scene's `environment_state.conditions`
    ///   - values: the environment as measured
    /// - Returns: each condition's chosen value; a condition no selector matched is left out, and
    ///   nothing is chosen until the window is measured
    @MainActor
    static func chooseEnvironment(
        _ conditions: [String: [ThomasEnvironmentConditionSelector]]?,
        values: ThomasEnvironmentState.Values
    ) -> [String: AirshipJSON] {
        let geometry = values.geometry
        // Before then no range can match, so a catch-all would win and flip on the first measure.
        guard geometry.window != nil else { return [:] }
        let shared = ThomasSelectorEnvironment(
            darkMode: values.traits.darkMode,
            windowSize: values.traits.windowSize,
            orientation: values.orientation
        )
        return choose(conditions) { selector in
            selector.matches(shared)
                && ThomasLengthRange.allows(selector.windowWidth, geometry.window?.width)
                && ThomasLengthRange.allows(selector.windowHeight, geometry.window?.height)
                && ThomasLengthRange.allows(selector.safeWindowWidth, geometry.safeWindow?.width)
                && ThomasLengthRange.allows(selector.safeWindowHeight, geometry.safeWindow?.height)
                && ThomasLengthRange.allows(selector.frameWidth, geometry.frame?.width)
                && ThomasLengthRange.allows(selector.frameHeight, geometry.frame?.height)
        } value: { $0.value }
    }

    /// Chooses each grid condition's value from the grid's content width.
    ///
    /// - Parameters:
    ///   - conditions: the grid's `grid_state.conditions`
    ///   - width: the grid's content width, or `nil` for a grid with none to measure
    /// - Returns: each condition's chosen value; a condition no selector matched is left out
    static func chooseGrid(
        _ conditions: [String: [ThomasGridConditionSelector]]?,
        width: CGFloat?
    ) -> [String: AirshipJSON] {
        choose(conditions) { ThomasLengthRange.allows($0.width, width) } value: { $0.value }
    }

    private static func choose<Selector>(
        _ conditions: [String: [Selector]]?,
        matches: (Selector) -> Bool,
        value: (Selector) -> AirshipJSON
    ) -> [String: AirshipJSON] {
        (conditions ?? [:]).compactMapValues { selectors in selectors.first(where: matches).map(value) }
    }
}
