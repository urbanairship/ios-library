/* Copyright Airship and Contributors */

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

@available(tvOS, unavailable)
@available(watchOS, unavailable)
protocol AirshipPasteboardProtocol: Sendable {
    func copy(value: String, expiry: TimeInterval)
    func copy(value: String)
}

@available(tvOS, unavailable)
@available(watchOS, unavailable)
struct DefaultAirshipPasteboard: AirshipPasteboardProtocol {

    func copy(value: String, expiry: TimeInterval) {
        #if os(macOS)
        // macOS pasteboard doesn't support expiration dates natively for simple strings
        self.copy(value: value)
        #else
        // iOS, visionOS
        let expirationDate = Date().advanced(by: expiry)
        UIPasteboard.general.setItems(
            [[UIPasteboard.typeAutomatic: value]],
            options: [
                UIPasteboard.OptionsKey.expirationDate: expirationDate
            ]
        )
        #endif
    }

    func copy(value: String) {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(value, forType: .string)
        #else
        // iOS, visionOS
        UIPasteboard.general.string = value
        #endif
    }
}
