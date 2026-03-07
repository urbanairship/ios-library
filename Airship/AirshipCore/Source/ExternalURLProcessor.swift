/* Copyright Airship and Contributors */

public import Foundation

#if canImport(UIKit)
import UIKit
#endif

#if canImport(WatchKit)
import WatchKit
#endif

#if canImport(AppKit)
import AppKit
#endif

/// Protocol for opening URLs and settings across different platforms.
public protocol URLOpenerProtocol: Sendable {
    /// Opens a URL asynchronously.
    @MainActor
    @discardableResult
    func openURL(_ url: URL) async -> Bool

    /// Opens a URL with a completion handler.
    @MainActor
    func openURL(_ url: URL, completionHandler: (@MainActor @Sendable (Bool) -> Void)?)

    /// Opens the app or system settings.
    @MainActor
    @discardableResult
    func openSettings() async -> Bool
}

/// Default implementation of the URLOpenerProtocol.
public struct DefaultURLOpener: URLOpenerProtocol {

    @MainActor
    public static let shared = DefaultURLOpener()

    @MainActor
    @discardableResult
    public func openURL(_ url: URL) async -> Bool {
#if os(macOS)
        return NSWorkspace.shared.open(url)
#elseif os(watchOS)
        WKExtension.shared().openSystemURL(url)
        return true
#else
        return await UIApplication.shared.open(url, options: [:])
#endif
    }

    @MainActor
    public func openURL(_ url: URL, completionHandler: (@MainActor @Sendable (Bool) -> Void)?) {
#if os(macOS)
        let success = NSWorkspace.shared.open(url)
        completionHandler?(success)
#elseif os(watchOS)
        WKExtension.shared().openSystemURL(url)
        completionHandler?(true)
#else
        UIApplication.shared.open(url, options: [:], completionHandler: completionHandler)
#endif
    }

    @MainActor
    public func openSettings() async -> Bool {
#if os(macOS)
        // Parity: Opens the app's own Settings window (Command + ,)
        // macOS users expect this for "App Settings" deep links.
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        return true
#elseif os(watchOS)
        // watchOS does not support opening settings via URL
        return false
#else
        // iOS, tvOS, visionOS
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return false
        }
        return await self.openURL(url)
#endif
    }
}
