/* Copyright Airship and Contributors */

import Combine
import Foundation
import SwiftUI
@_spi(AirshipInternal) import AirshipBasement

/// The platform and window a scene is drawn in, published to state as `$environment`.
///
/// Read-only: `RootView` recomputes it from the platform. A state action never sets it, and it is
/// never saved, restored, or submitted with a form.
@MainActor
final class ThomasEnvironmentState: ObservableObject {

    /// The state key the values are published under.
    static let stateKey: String = "$environment"

    /// The shortest gap between two geometry publishes while a window is being resized.
    static let geometryUpdateInterval: TimeInterval = 0.1

    @Published private(set) var values: Values

    /// The scene's `environment_state.conditions`, chosen again whenever the values change.
    private let conditions: [String: [ThomasEnvironmentConditionSelector]]?
    private let taskSleeper: any AirshipTaskSleeper
    private var pendingGeometry: Geometry?
    private var geometryCooldown: Task<Void, Never>?

    init(
        values: Values,
        conditions: [String: [ThomasEnvironmentConditionSelector]]? = nil,
        taskSleeper: any AirshipTaskSleeper = DefaultAirshipTaskSleeper.shared
    ) {
        self.conditions = conditions
        self.values = values.choosing(conditions)
        self.taskSleeper = taskSleeper
    }

    deinit {
        geometryCooldown?.cancel()
    }

    /// Publishes new traits at once, along with the latest geometry reported.
    ///
    /// - Parameter traits: The traits the platform reports now.
    func update(traits: Traits) {
        guard traits != values.traits else { return }
        values = Values(traits: traits, geometry: pendingGeometry ?? values.geometry).choosing(conditions)
        pendingGeometry = nil
    }

    /// Publishes the window's size, throttled as `updateGeometry(_:)` describes.
    ///
    /// - Parameters:
    ///   - window: The window's size before safe-area insets.
    ///   - safeWindow: The window's size less its safe-area insets.
    func update(window: CGSize, safeWindow: CGSize) {
        updateGeometry {
            $0.window = window
            $0.safeWindow = safeWindow
        }
    }

    /// Publishes the space the host gives the scene, throttled as `updateGeometry(_:)` describes.
    ///
    /// - Parameter frame: The host's bounds, with an axis the scene's content decides left nil.
    func update(frame: HostFrame) {
        updateGeometry { $0.frame = frame }
    }

    /// Publishes a geometry change at once and then at most once per `geometryUpdateInterval`,
    /// always ending on the last geometry reported.
    ///
    /// A resize reports sizes every frame, and every publish re-evaluates every predicate in the
    /// tree. Empty sizes are ignored, so an unlaid-out view can't replace a measured one.
    ///
    /// - Parameter change: Applies the reported size to the latest geometry.
    private func updateGeometry(_ change: (inout Geometry) -> Void) {
        let latest = pendingGeometry ?? values.geometry
        var next = latest
        change(&next)
        guard next.isMeasured, next != latest else { return }

        guard geometryCooldown == nil else {
            pendingGeometry = next
            return
        }

        var updated = values
        updated.geometry = next
        values = updated.choosing(conditions)
        startGeometryCooldown()
    }

    private func startGeometryCooldown() {
        geometryCooldown = Task { @MainActor [weak self, taskSleeper] in
            try? await taskSleeper.sleep(timeInterval: Self.geometryUpdateInterval)
            guard let self, !Task.isCancelled else { return }
            self.geometryCooldown = nil
            guard let pending = self.pendingGeometry else { return }
            self.pendingGeometry = nil
            self.updateGeometry { $0 = pending }
        }
    }

    /// The values that change without the window being resized.
    struct Traits: Equatable, Sendable {
        /// Whether the system appearance is dark, which is what color selectors' `dark_mode` matches.
        var darkMode: Bool

        /// The scale applied to label text, 1 at the default size.
        var textScale: Double

        /// The window's size class, the same one `window_size` placement selectors match.
        var windowSize: ThomasWindowSize

        /// The direction the host lays content out in.
        var layoutDirection: LayoutDirection

        /// SwiftUI's locale, which is the current locale unless the app overrides it. Airship's own
        /// locale override is not applied.
        var locale: Locale
    }

    /// The bounds of the view a scene is presented in, before the placement and safe-area insets.
    struct HostFrame: Equatable, Sendable {
        /// Nil when the host lets the scene's content decide the width.
        var width: CGFloat?

        /// Nil when the host lets the scene's content decide the height, like an auto-height embedded view.
        var height: CGFloat?
    }

    /// The sizes the scene is drawn at, each nil until it has been measured.
    struct Geometry: Equatable, Sendable {
        /// The window's size before safe-area insets.
        var window: CGSize?

        /// The window's size less its safe-area insets.
        var safeWindow: CGSize?

        /// The space the host gives the scene: the presenting view's bounds for a modal or banner,
        /// and the embedded view's own bounds.
        var frame: HostFrame?

        /// Whether every length present is non-zero.
        fileprivate var isMeasured: Bool {
            let lengths: [CGFloat?] = [
                window?.width, window?.height,
                safeWindow?.width, safeWindow?.height,
                frame?.width, frame?.height
            ]
            return lengths.allSatisfy { $0.map { $0 > 0 } ?? true }
        }
    }

    /// The environment as measured, and the environment conditions chosen from it.
    struct Values: Equatable, Sendable {
        var traits: Traits
        var geometry: Geometry = Geometry()
        /// Each environment condition's chosen value; a condition no selector matched is left out.
        var conditions: [String: AirshipJSON] = [:]

        /// The window's orientation, or `nil` until the window is measured.
        var orientation: ThomasOrientation? {
            geometry.window.map { $0.width > $0.height ? .landscape : .portrait }
        }

        /// Returns the values with `conditions` chosen from them.
        ///
        /// - Parameter declared: the scene's `environment_state.conditions`
        /// - Returns: the values, conditions chosen
        @MainActor
        func choosing(_ declared: [String: [ThomasEnvironmentConditionSelector]]?) -> Values {
            var copy = self
            copy.conditions = ThomasConditions.chooseEnvironment(declared, values: self)
            return copy
        }

        /// Returns the values as the `$environment` state object.
        ///
        /// The window, safe window and frame sizes stay out, so a resize that crosses no
        /// breakpoint changes nothing a predicate reads; conditions carry what a scene needs.
        ///
        /// - Returns: The state object.
        var json: AirshipJSON {
            var window: [String: AirshipJSON] = ["size": .string(traits.windowSize.rawValue)]
            window["orientation"] = orientation.map { .string($0.rawValue) }

            return .object([
                "platform": .string("ios"),
                "dark_mode": .bool(traits.darkMode),
                "text_scale": .number(traits.textScale),
                "layout_direction": .string(traits.layoutDirection == .rightToLeft ? "rtl" : "ltr"),
                "locale": .object(Self.localeJSON(traits.locale)),
                "window": .object(window),
                "conditions": .object(conditions)
            ])
        }

        /// Returns the locale as its BCP 47 identifier and its parts, so a predicate can match
        /// every region of a language by `language` alone.
        private static func localeJSON(_ locale: Locale) -> [String: AirshipJSON] {
            var result: [String: AirshipJSON] = [
                "identifier": .string(locale.identifier(.bcp47))
            ]
            result["language"] = locale.language.languageCode.map { .string($0.identifier) }
            result["region"] = locale.region.map { .string($0.identifier) }
            return result
        }
    }

    /// The scale the platform applies to label text, which `text_scaled` widths also multiply by.
    static var currentTextScale: Double {
        AirshipFont.scaledSize(100) / 100
    }
}

extension ThomasEnvironmentState.Values {

    /// Returns the values UIKit reports before SwiftUI has laid anything out.
    ///
    /// A state trigger evaluates on the first pass and doesn't fire again, so the first pass needs
    /// real values rather than placeholders that `RootView` corrects a moment later.
    ///
    /// - Parameter window: The window's size at display time, or `.zero` when the caller has none.
    /// - Returns: The seed values.
    @MainActor
    static func seed(window: CGSize) -> Self {
        let measured: CGSize? = window.width > 0 && window.height > 0 ? window : nil
#if canImport(UIKit) && !os(watchOS)
        let traits = UITraitCollection.current
        return Self(
            traits: .init(
                darkMode: traits.userInterfaceStyle == .dark,
                textScale: ThomasEnvironmentState.currentTextScale,
                windowSize: windowSize(traits),
                layoutDirection: traits.layoutDirection == .rightToLeft ? .rightToLeft : .leftToRight,
                locale: .current
            ),
            geometry: .init(window: measured)
        )
#else
        return Self(
            traits: .init(
                darkMode: false,
                textScale: ThomasEnvironmentState.currentTextScale,
                windowSize: .small,
                layoutDirection: .leftToRight,
                locale: .current
            ),
            geometry: .init(window: measured)
        )
#endif
    }

#if canImport(UIKit) && !os(watchOS)
    /// Returns the window size class `RootView.resolveWindowSize()` resolves, read from UIKit.
    ///
    /// - Parameter traits: The trait collection to read the size classes from.
    /// - Returns: The window size class.
    private static func windowSize(_ traits: UITraitCollection) -> ThomasWindowSize {
#if os(tvOS)
        return .large
#else
        return switch (traits.verticalSizeClass, traits.horizontalSizeClass) {
        case (.regular, .regular): .large
        case (.compact, .compact): .small
        default: .medium
        }
#endif
    }
#endif
}

private struct ThomasEnvironmentStateKey: EnvironmentKey {
    static let defaultValue: ThomasEnvironmentState? = nil
}

extension EnvironmentValues {
    /// The scene's `$environment` source, set by `RootView` for the presentations to report into.
    var thomasEnvironmentState: ThomasEnvironmentState? {
        get { self[ThomasEnvironmentStateKey.self] }
        set { self[ThomasEnvironmentStateKey.self] = newValue }
    }
}

extension View {
    /// Reports `frame` as `$environment.frame` whenever it changes.
    ///
    /// - Parameter frame: The bounds of the view the scene is presented in.
    /// - Returns: The view, reporting `frame`.
    func reportsHostFrame(_ frame: ThomasEnvironmentState.HostFrame) -> some View {
        modifier(HostFrameReporter(frame: frame))
    }
}

private struct HostFrameReporter: ViewModifier {
    let frame: ThomasEnvironmentState.HostFrame
    @Environment(\.thomasEnvironmentState) private var environmentState

    func body(content: Content) -> some View {
        content.airshipOnChangeOf(frame, initial: true) { frame in
            environmentState?.update(frame: frame)
        }
    }
}
