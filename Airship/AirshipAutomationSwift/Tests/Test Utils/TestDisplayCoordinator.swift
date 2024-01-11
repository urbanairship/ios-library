/* Copyright Airship and Contributors */

import Foundation
import Combine

@testable import AirshipAutomationSwift
@testable import AirshipCore

class TestDisplayCoordinator: DisplayCoordinator {
    var isReady: Bool = true

    func messageWillDisplay(_ message: InAppMessage) {

    }

    func messageFinishedDisplaying(_ message: InAppMessage) {

    }

    func waitForReady() async {
        
    }
}
