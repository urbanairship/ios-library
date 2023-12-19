/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Controls the display of an In-App message
@MainActor
protocol DisplayCoordinator: Sendable {
    var isReady: Bool { get }
    func didBeginDisplayingMessage(_ message: InAppMessage)
    func didFinishDisplayingMessage(_ message: InAppMessage)
    func waitForReady() async
}
