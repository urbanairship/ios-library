/* Copyright Airship and Contributors */

import Foundation
@testable import AirshipAutomation

import AirshipCore
@_spi(AirshipInternal) import AirshipBasement

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
