import Foundation
import AirshipCore

@objc(UATestAppStateTracker)
public class TestAppStateTracker : AppStateTracker {

    @objc
    public var currentState : ApplicationState = .background

    public override var state: ApplicationState {
        return currentState
    }
}
