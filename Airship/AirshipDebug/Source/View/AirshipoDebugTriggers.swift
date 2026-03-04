/* Copyright Airship and Contributors */

public import SwiftUI
import AirshipCore

#if canImport(UIKit)
import UIKit
#endif

/// Defines the triggers available for the Airship Debug interface.
public struct AirshipDebugTrigger: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    /// Detects device shake (iOS only).
    public static let shake = AirshipDebugTrigger(rawValue: 1 << 0)
    /// Detects Cmd + Shift + D (iOS with hardware keyboard & macOS).
    public static let cmdShiftD = AirshipDebugTrigger(rawValue: 1 << 1)
}

public extension View {
    /// Enables the Airship Debug interface based on specified interaction triggers.
    ///
    /// This modifier provides a unified way to access the Airship Debug console across platforms.
    ///
    /// The debug interface will only be attached if `Airship.isFlying` is true and
    /// `isAirshipDebugEnabled` is set to `true` in the Airship configuration.
    ///
    /// ### Usage
    /// ```swift
    /// // Standard behavior (Shake & Hotkey)
    /// ContentView()
    ///     .airshipDebug(triggers: [.shake, .cmdShiftD)
    ///
    /// // Discrete mode (keyboard only)
    /// ContentView()
    ///     .airshipDebug(triggers: [.cmdShiftD])
    /// ```
    ///
    /// - Parameter triggers: A set of ``AirshipDebugTrigger`` options determining how the
    ///   debug interface is invoked. Defaults to ``AirshipDebugTrigger/defaultTriggers``.
    /// - Returns: A view modified to detect the specified debug triggers.
    @ViewBuilder
    func airshipDebug(triggers: AirshipDebugTrigger) -> some View {
        if Airship.isFlying, Airship.config.airshipConfig.isAirshipDebugEnabled {
            self.modifier(AirshipDebugModifier(triggers: triggers))
        } else {
            self
        }
    }

    /// Enables the Airship Debug interface via a device shake gesture.
    ///
    /// This is a legacy convenience method for iOS that specifically enables the
    /// shake gesture trigger. For more control, use ``airshipDebug(triggers:)``.
    @available(*, deprecated, renamed: "airshipDebug(triggers:)", message: "Use airshipDebug(triggers: .shake) instead.")
    func airshipDebugOnShake() -> some View {
        self.airshipDebug(triggers: .shake)
    }
}

struct AirshipDebugModifier: ViewModifier {
    let triggers: AirshipDebugTrigger

    func body(content: Content) -> some View {
        content
            // --- Gestures (iOS) ---
#if canImport(UIKit)
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.airshipDeviceDidShakeNotification)) { _ in
                if triggers.contains(.shake) { displayDebug() }
            }
#endif
            .airshipApplyIf(triggers.contains(.cmdShiftD)) { view in
                view.background {
                    Button("") {
                        displayDebug()
                    }
                    .keyboardShortcut("d", modifiers: [.command, .shift])
                    .opacity(0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
    }

    private func displayDebug() {
        Airship.debugManager.display()
    }
}

// MARK: - iOS Specific Shake Logic
#if canImport(UIKit)
extension UIDevice {
    static let airshipDeviceDidShakeNotification = Notification.Name(rawValue: "AirshipDeviceDidShakeNotification")
}

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: UIDevice.airshipDeviceDidShakeNotification, object: nil)
        }
        super.motionEnded(motion, with: event)
    }
}
#endif
