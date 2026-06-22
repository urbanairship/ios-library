/* Copyright Airship and Contributors */

import Foundation

import AirshipCore

/// Controls the display of an In-App message
@MainActor
protocol DisplayCoordinator: AnyObject, Sendable {
    var isReady: Bool { get }
    func messageWillDisplay(_ message: InAppMessage)
    func messageFinishedDisplaying(_ message: InAppMessage)
    func waitForReady() async
}
