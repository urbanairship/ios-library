/* Copyright Airship and Contributors */

import Foundation

#if canImport(UIKit)
import UIKit
#endif

#if canImport(WatchKit)
import WatchKit
#endif


protocol URLOpenerProtocol: Sendable {
    @MainActor
    func openURL(_ url: URL) async -> Bool
}


struct DefaultURLOpener: URLOpenerProtocol {
    @MainActor
    func openURL(_ url: URL) async -> Bool {
#if !os(watchOS)
            return await UIApplication.shared.open(url, options: [:])
#else
            WKExtension.shared().openSystemURL(url)
            return true
#endif
    }
}
