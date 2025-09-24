/* Copyright Airship and Contributors */

public import SwiftUI
import UIKit
import AirshipCore


/// A view modifier that detects device shake gestures and displays the Airship debug interface.
///
/// This modifier listens for shake gestures and automatically displays the Airship
/// debug interface when a shake is detected. It only works in debug builds and
/// is automatically disabled in release builds.
///
/// ## Usage
///
/// ```swift
/// ContentView()
///     .airshipDebugOnShake()
/// ```
///
/// - Note: This modifier only works in debug builds and requires proper shake detection setup.
public extension View {
    /// Adds shake gesture detection to display the Airship debug interface.
    ///
    /// This modifier detects device shake gestures and automatically displays
    /// the Airship debug interface when a shake is detected.
    ///
    func airshipDebugOnShake() -> some View {
        self.modifier(AirshipDebugShakeModifier())
    }
}

/// A view modifier that handles shake gesture detection for the Airship debug interface.
struct AirshipDebugShakeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.airshipDeviceDidShakeNotification)) { _ in
                guard Airship.isFlying, Airship.config.airshipConfig.isAirshipDebugEnabled else {
                    print("🚫 AirshipDebug: isAirshipDebugEnabled disabled, unable to display debug view")
                    return
                }
                Airship.debugManager.display()
            }
    }
}

/// Notification name for device shake detection.
extension UIDevice {
    static let airshipDeviceDidShakeNotification = Notification.Name(rawValue: "AirshipDeviceDidShakeNotification")
}

/// UIWindow extension to detect shake gestures and post notifications.
extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: UIDevice.airshipDeviceDidShakeNotification, object: nil)
        }
        super.motionEnded(motion, with: event)
    }
}
