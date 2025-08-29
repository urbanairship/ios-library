/* Copyright Airship and Contributors */

import Foundation
@testable import AirshipAutomation

import AirshipCore

@MainActor
final class TestActiveTimer: AirshipTimerProtocol {
    var time: TimeInterval = 0
    var isStarted: Bool = false

    func start() {
        isStarted = true
    }
    
    func stop() {
        isStarted = false
    }
}
