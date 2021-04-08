/* Copyright Airship and Contributors */

@testable
import AirshipChat
import AirshipCore

class MockAppStateTracker : UAAppStateTracker {
    var mockState: UAApplicationState = UAApplicationState.background

    override var state: UAApplicationState {
        get {
            return self.mockState
        }
    }
}
