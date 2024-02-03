/* Copyright Airship and Contributors */

import Foundation
@testable import AirshipAutomation

@MainActor
final class TestActiveTimer: ActiveTimerProtocol {
    var time: TimeInterval = 0
    var isStarted: Bool = false

    func start() {
        isStarted = true
    }
    
    func stop() {
        isStarted = false
    }
}
