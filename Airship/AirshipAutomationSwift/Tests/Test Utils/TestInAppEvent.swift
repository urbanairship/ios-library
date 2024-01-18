/* Copyright Airship and Contributors */

import Foundation

@testable import AirshipAutomationSwift

struct TestInAppEvent: InAppEvent {
    var name: String
    var data: (any Encodable & Sendable)?

    init(name: String = "test_event", data: (Encodable & Sendable)? = nil) {
        self.name = name
        self.data = data
    }
}


