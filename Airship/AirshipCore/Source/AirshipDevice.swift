/* Copyright Airship and Contributors */

import Foundation

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif


#if canImport(WatchKit)
import WatchKit
#endif


/// Internal helper for platform-specific device info.
/// NOTE: For internal use only. :nodoc:
public struct AirshipDevice: Sendable {

    /// Returns the device model name (e.g., "iPhone14,3" or "MacBookPro18,1")
    public static let modelIdentifier: String = {
#if targetEnvironment(macCatalyst)
        return "mac"
#elseif os(macOS)
        // Native macOS
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)

        let bytes = model.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes.dropLast(), as: UTF8.self)
#else
        // iOS / tvOS / etc
        var systemInfo = utsname()
        uname(&systemInfo)

        // Use withUnsafePointer to convert the C-char tuple to a String safely
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(_SYS_NAMELEN)) {
                String(cString: $0)
            }
        }
#endif
    }()

    /// The generic device category (e.g., "iPhone", "iPad").
    /// Matches the legacy UIDevice.current.model.
    @MainActor
    public static var model: String {
#if os(iOS) || os(tvOS) || os(visionOS)
        return UIDevice.current.model
#elseif os(watchOS)
        return WKInterfaceDevice.current().model
#else
        return "Mac"
#endif
    }

    /// Returns the system name (e.g., "iOS", "tvOS", "watchOS").
        /// This matches UIDevice.current.systemName on Apple platforms.
        @MainActor
    public static var deviceFamily: String {
#if os(watchOS)
        return WKInterfaceDevice.current().systemName
#elseif canImport(UIKit)
        return UIDevice.current.systemName
#elseif os(macOS)
        return "macOS"
#else
        return "Unknown"
#endif
    }

    /// Returns the OS name
    public static var osName: String {
#if os(macOS)
        return "macOS"
#elseif targetEnvironment(macCatalyst)
        // Catalyst returns true for os(iOS), so check this first
        return "macOS"
#elseif os(visionOS)
        return "visionOS"
#elseif os(tvOS)
        return "tvOS"
#elseif os(iOS)
        return "iOS"
#else
        return "Unknown"
#endif
    }

    /// Returns the OS Version string
    @MainActor
    public static var osVersion: String {
#if os(watchOS)
        return WKInterfaceDevice.current().systemVersion
#elseif os(macOS)
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
#elseif canImport(UIKit)
        return UIDevice.current.systemVersion
#else
        return "0.0.0"
#endif
    }
}
