/* Copyright Airship and Contributors */

@testable
import AirshipChat
import AirshipCore

class MockAppStateTracker : AppStateTracker {
    var mockState: ApplicationState = ApplicationState.background

    override var state: ApplicationState {
        get {
            return self.mockState
        }
    }
}
