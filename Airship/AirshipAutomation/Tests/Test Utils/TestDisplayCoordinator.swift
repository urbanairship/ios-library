/* Copyright Airship and Contributors */

import Foundation
import Combine

@testable @_spi(AirshipInternal) import AirshipAutomation
@testable import AirshipCore

class TestDisplayCoordinator: DisplayCoordinator {
    var isReady: Bool = true
    private(set) var willDisplayCount: Int = 0
    private(set) var finishedDisplayingCount: Int = 0

    func messageWillDisplay(_ message: InAppMessage) {
        willDisplayCount += 1
    }

    func messageFinishedDisplaying(_ message: InAppMessage) {
        finishedDisplayingCount += 1
    }

    func waitForReady() async {
        
    }
}
